## In-process WebSocket game server for LAN multiplayer.
## Runs in the host's game process. Manages lobby, match, and event broadcast.
class_name GameServer
extends Node

signal player_joined(peer_id: int, name: String)
signal player_left(peer_id: int)
signal match_started()
signal lobby_updated()

var _server: WebSocketMultiplayerPeer
var _port: int = 19735
var _running: bool = false

## Lobby state
var players: Dictionary = {}  ## {peer_id: {name, slot, ready}}
var host_name: String = "Host"
var max_players: int = 8
var _next_slot: int = 1  ## slot 0 is host

## Match state (server-authoritative)
var match_flow: MatchFlow
var config: GameConfig


func start(port: int = 19735, p_host_name: String = "Host") -> Error:
	_port = port
	host_name = p_host_name
	_server = WebSocketMultiplayerPeer.new()
	var err := _server.create_server(_port)
	if err != OK:
		return err

	multiplayer.multiplayer_peer = _server
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_running = true

	# Host is player 0
	players[1] = {"name": host_name, "slot": 0, "ready": true}
	return OK


func stop() -> void:
	_running = false
	if _server:
		_server.close()
	players.clear()


func get_port() -> int:
	return _port


func is_running() -> bool:
	return _running


func get_player_count() -> int:
	return players.size()


## Start the match (host only).
func start_match(p_config: GameConfig) -> void:
	config = p_config
	config.player_count = players.size()

	# Broadcast config
	var config_data := _serialize_config(config)
	_broadcast(NetProtocol.config_msg(config_data))
	_broadcast(NetProtocol.start_msg())

	# Create server-side match
	match_flow = MatchFlow.new(config)
	match_flow.start()

	# Wire cursor spawn → broadcast
	match_flow.turn_director.cursor_spawned.connect(func(idx: int) -> void:
		_broadcast(NetProtocol.cursor_msg(idx, config.cursor_expire_time)))

	# Wire action events → broadcast
	match_flow.action_events.connect(func(events: Array) -> void:
		var actor: int = events[0]["actor_id"] if events.size() > 0 else -1
		_broadcast(NetProtocol.events_msg(actor, events)))

	# Wire match end
	match_flow.match_ended.connect(func(summary: Dictionary) -> void:
		_broadcast(NetProtocol.match_end_msg(summary)))

	match_started.emit()


func _process(delta: float) -> void:
	if not _running:
		return
	if match_flow and match_flow.state == MatchFlow.State.PLAYING:
		match_flow.tick(delta)
		match_flow.on_animation_complete()  # Server doesn't animate


func _on_peer_connected(peer_id: int) -> void:
	# Will be registered when they send JOIN message
	pass


func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id in players:
		var name: String = players[peer_id]["name"]
		players.erase(peer_id)
		player_left.emit(peer_id)
		_broadcast({"type": NetProtocol.MSG_PLAYER_LEFT, "peer": peer_id, "name": name})
		lobby_updated.emit()


## Handle incoming message from a client.
func handle_message(peer_id: int, text: String) -> void:
	var msg := NetProtocol.decode(text)
	if msg.is_empty():
		return

	var msg_type: String = msg.get("type", "")

	match msg_type:
		NetProtocol.MSG_JOIN:
			_handle_join(peer_id, msg)
		NetProtocol.MSG_ACTION:
			_handle_action(peer_id, msg)
		NetProtocol.MSG_PING:
			var response := NetProtocol.pong_msg(
				msg.get("time", 0.0), Time.get_ticks_msec() / 1000.0)
			_send_to(peer_id, response)


func _handle_join(peer_id: int, msg: Dictionary) -> void:
	if players.size() >= max_players:
		_send_to(peer_id, {"type": NetProtocol.MSG_ERROR, "msg": "Room full"})
		return
	var name: String = msg.get("name", "Player")
	players[peer_id] = {"name": name, "slot": _next_slot, "ready": true}
	_next_slot += 1
	player_joined.emit(peer_id, name)
	_broadcast_lobby()
	lobby_updated.emit()


func _handle_action(peer_id: int, msg: Dictionary) -> void:
	if match_flow == null or match_flow.state != MatchFlow.State.PLAYING:
		return
	if peer_id not in players:
		return
	var slot: int = players[peer_id]["slot"]
	var direction: int = msg.get("dir", -1)
	match_flow.submit_action(slot, direction)


func _broadcast(msg: Dictionary) -> void:
	if not _running or _server == null:
		return
	var text := NetProtocol.encode(msg)
	# Send to all connected peers
	for peer_id: int in players:
		if peer_id == 1:
			continue  # Skip host (handled locally)
		_send_text_to(peer_id, text)


func _send_to(peer_id: int, msg: Dictionary) -> void:
	_send_text_to(peer_id, NetProtocol.encode(msg))


func _send_text_to(peer_id: int, text: String) -> void:
	if _server:
		_server.get_peer(peer_id).put_packet(text.to_utf8_buffer())


func _broadcast_lobby() -> void:
	var player_list: Array = []
	for pid: int in players:
		player_list.append({"id": pid, "name": players[pid]["name"], "slot": players[pid]["slot"]})
	_broadcast(NetProtocol.lobby_state_msg(player_list, host_name))


func _serialize_config(cfg: GameConfig) -> Dictionary:
	return {
		"grid_size": cfg.grid_size,
		"capture_threshold": cfg.capture_threshold,
		"time_limit": cfg.time_limit,
		"player_count": cfg.player_count,
		"wrap_around": cfg.wrap_around,
		"board_shape": cfg.board_shape,
		"skip_blanks": cfg.skip_blanks,
		"allow_tap": cfg.allow_tap,
		"max_castles": cfg.max_castles,
		"scoring_mode": cfg.scoring_mode,
	}
