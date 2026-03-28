## WebSocket client for connecting to a Crystal Kingdoms game server.
class_name GameClient
extends Node

signal connected_to_server()
signal disconnected()
signal lobby_updated(players: Array, host: String)
signal match_starting(config_data: Dictionary)
signal cursor_spawned(index: int)
signal events_received(events: Array)
signal match_ended(summary: Dictionary)
signal ping_updated(ms: float)
signal error_received(msg: String)

var _client: WebSocketMultiplayerPeer
var _connected: bool = false
var player_name: String = "Player"
var my_slot: int = -1
var _ping_timer: float = 0.0

const PING_INTERVAL := 2.0


func connect_to_server(address: String, port: int = 19735, p_name: String = "Player") -> Error:
	player_name = p_name
	_client = WebSocketMultiplayerPeer.new()
	var url := "ws://%s:%d" % [address, port]
	var err := _client.create_client(url)
	if err != OK:
		return err

	multiplayer.multiplayer_peer = _client
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.server_disconnected.connect(_on_disconnected)
	return OK


func disconnect_from_server() -> void:
	_connected = false
	if _client:
		_client.close()


func is_connected_to_server() -> bool:
	return _connected


## Send a player action to the server.
func send_action(direction: int) -> void:
	if not _connected or my_slot < 0:
		return
	var msg := NetProtocol.action_msg(my_slot, direction,
		Time.get_ticks_msec() / 1000.0)
	_send(msg)


func _process(delta: float) -> void:
	if not _connected:
		return

	# Periodic ping
	_ping_timer -= delta
	if _ping_timer <= 0:
		_send(NetProtocol.ping_msg(Time.get_ticks_msec() / 1000.0))
		_ping_timer = PING_INTERVAL


func _on_connected() -> void:
	_connected = true
	# Send join
	_send(NetProtocol.join_msg(player_name))
	connected_to_server.emit()


func _on_disconnected() -> void:
	_connected = false
	disconnected.emit()


## Handle incoming message from server.
func handle_message(text: String) -> void:
	var msg := NetProtocol.decode(text)
	if msg.is_empty():
		return

	var msg_type: String = msg.get("type", "")
	match msg_type:
		NetProtocol.MSG_LOBBY_STATE:
			var players: Array = msg.get("players", [])
			# Find our slot
			for p: Dictionary in players:
				if p.get("name", "") == player_name:
					my_slot = p.get("slot", -1)
			lobby_updated.emit(players, msg.get("host", ""))

		NetProtocol.MSG_CONFIG:
			pass  # Config received, stored by lobby UI

		NetProtocol.MSG_START:
			match_starting.emit(msg.get("config", {}))

		NetProtocol.MSG_CURSOR_SPAWN:
			cursor_spawned.emit(msg.get("index", 0))

		NetProtocol.MSG_EVENTS:
			events_received.emit(msg.get("events", []))

		NetProtocol.MSG_MATCH_END:
			match_ended.emit(msg.get("summary", {}))

		NetProtocol.MSG_PONG:
			var client_time: float = msg.get("client_time", 0.0)
			var now := Time.get_ticks_msec() / 1000.0
			var rtt := (now - client_time) * 1000.0  # ms
			ping_updated.emit(rtt)

		NetProtocol.MSG_ERROR:
			error_received.emit(msg.get("msg", "Unknown error"))


func _send(msg: Dictionary) -> void:
	if _client:
		var text := NetProtocol.encode(msg)
		_client.get_peer(1).put_packet(text.to_utf8_buffer())
