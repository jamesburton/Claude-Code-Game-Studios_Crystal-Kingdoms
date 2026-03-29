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

## Latency tracking per peer (round-trip ms)
var peer_latency: Dictionary = {}  ## {peer_id: float ms}

## Action claim window: holds actions briefly to allow higher-latency
## players' earlier actions to arrive before resolving.
var _claim_window: float = 0.05  ## 50ms collection window
var _claim_timer: float = -1.0
var _pending_actions: Array = []  ## [{peer_id, slot, dir, client_time}]


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

		# Resolve claim window
		if _claim_timer >= 0:
			_claim_timer -= delta
			if _claim_timer <= 0:
				_resolve_claim_window()
				_claim_timer = -1.0


## Resolve pending actions: pick the one with the earliest adjusted timestamp.
func _resolve_claim_window() -> void:
	if _pending_actions.is_empty():
		return
	if match_flow == null or match_flow.state != MatchFlow.State.PLAYING:
		_pending_actions.clear()
		return

	# Sort by adjusted_time — earliest action wins
	_pending_actions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["adjusted_time"] < b["adjusted_time"])

	# Submit only the winning action
	var winner: Dictionary = _pending_actions[0]
	match_flow.submit_action(winner["slot"], winner["dir"])

	_pending_actions.clear()


func _on_peer_connected(peer_id: int) -> void:
	# Will be registered when they send JOIN message
	pass


func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id in players:
		var p_name: String = players[peer_id]["name"]
		var slot: int = players[peer_id]["slot"]
		players.erase(peer_id)
		player_left.emit(peer_id)
		_broadcast({"type": NetProtocol.MSG_PLAYER_LEFT, "peer": peer_id, "name": p_name})
		lobby_updated.emit()

		# If match is running, replace disconnected player with CPU
		if match_flow and match_flow.state == MatchFlow.State.PLAYING:
			var med := load("res://src/data/cpu_difficulty_medium.tres") as CpuDifficulty
			if med:
				match_flow.add_cpu(slot, med)


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
			var client_time: float = msg.get("time", 0.0)
			var server_time := Time.get_ticks_msec() / 1000.0
			_send_to(peer_id, NetProtocol.pong_msg(client_time, server_time))
			# Estimate latency from round trip (client sends time, we respond)
			# Actual RTT measured client-side; server stores last known value
		NetProtocol.MSG_LATENCY_REPORT:
			peer_latency[peer_id] = msg.get("rtt", 0.0)


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
	var client_time: float = msg.get("time", 0.0)

	# Adjust client timestamp by half their round-trip latency
	# to estimate when the action was actually taken
	var latency_offset: float = peer_latency.get(peer_id, 0.0) / 2000.0  # half RTT in seconds
	var adjusted_time: float = client_time - latency_offset

	_pending_actions.append({
		"peer_id": peer_id,
		"slot": slot,
		"dir": direction,
		"adjusted_time": adjusted_time,
	})

	# Start the collection window if not already running
	if _claim_timer < 0:
		_claim_timer = _claim_window


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
