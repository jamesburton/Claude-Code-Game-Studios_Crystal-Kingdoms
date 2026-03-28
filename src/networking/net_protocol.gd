## Network protocol messages for Crystal Kingdoms multiplayer.
## All messages are JSON-encoded dictionaries sent over WebSocket.
class_name NetProtocol
extends RefCounted

## Message types
const MSG_JOIN := "join"             ## Client → Server: request to join room
const MSG_LOBBY_STATE := "lobby"     ## Server → Client: room/player state
const MSG_CONFIG := "config"         ## Server → All: match config at start
const MSG_START := "start"           ## Server → All: match is starting
const MSG_CURSOR_SPAWN := "cursor"   ## Server → All: cursor spawned at index
const MSG_ACTION := "action"         ## Client → Server: player action
const MSG_EVENTS := "events"         ## Server → All: resolved event log
const MSG_MATCH_END := "match_end"   ## Server → All: match over with summary
const MSG_PING := "ping"             ## Client ↔ Server: latency measurement
const MSG_PONG := "pong"
const MSG_PLAYER_LEFT := "left"      ## Server → All: player disconnected
const MSG_ERROR := "error"           ## Server → Client: error message


static func encode(msg: Dictionary) -> String:
	return JSON.stringify(msg)


static func decode(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}


## Create common message constructors

static func join_msg(player_name: String) -> Dictionary:
	return {"type": MSG_JOIN, "name": player_name}


static func lobby_state_msg(players: Array, host_name: String) -> Dictionary:
	return {"type": MSG_LOBBY_STATE, "players": players, "host": host_name}


static func config_msg(config_data: Dictionary) -> Dictionary:
	return {"type": MSG_CONFIG, "config": config_data}


static func start_msg() -> Dictionary:
	return {"type": MSG_START}


static func cursor_msg(index: int, expire_time: float) -> Dictionary:
	return {"type": MSG_CURSOR_SPAWN, "index": index, "expire": expire_time}


static func action_msg(player_id: int, direction: int, timestamp: float) -> Dictionary:
	return {"type": MSG_ACTION, "player": player_id, "dir": direction, "time": timestamp}


static func events_msg(actor_id: int, events: Array) -> Dictionary:
	return {"type": MSG_EVENTS, "actor": actor_id, "events": events}


static func match_end_msg(summary: Dictionary) -> Dictionary:
	return {"type": MSG_MATCH_END, "summary": summary}


static func ping_msg(client_time: float) -> Dictionary:
	return {"type": MSG_PING, "time": client_time}


static func pong_msg(client_time: float, server_time: float) -> Dictionary:
	return {"type": MSG_PONG, "client_time": client_time, "server_time": server_time}
