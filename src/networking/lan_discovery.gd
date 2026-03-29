## LAN game discovery via UDP broadcast.
## Host broadcasts presence; clients listen for nearby games.
class_name LanDiscovery
extends Node

signal server_found(address: String, port: int, host_name: String, player_count: int)
signal server_lost(address: String)

const BROADCAST_PORT := 19736
const BROADCAST_INTERVAL := 2.0
const TIMEOUT := 6.0
const MAGIC := "CK_LAN"

var _broadcast_peer: PacketPeerUDP
var _listen_peer: PacketPeerUDP
var _broadcasting: bool = false
var _listening: bool = false
var _broadcast_timer: float = 0.0
var _host_name: String = "Host"
var _game_port: int = 19735
var _player_count: int = 1

## Known servers: {address: {host_name, port, player_count, last_seen}}
var known_servers: Dictionary = {}


## Start broadcasting this server's presence.
func start_broadcasting(host_name: String, game_port: int, player_count: int) -> void:
	_host_name = host_name
	_game_port = game_port
	_player_count = player_count
	_broadcast_peer = PacketPeerUDP.new()
	_broadcast_peer.set_broadcast_enabled(true)
	_broadcast_peer.set_dest_address("255.255.255.255", BROADCAST_PORT)
	_broadcasting = true
	_broadcast_timer = 0.0


## Start listening for server broadcasts.
func start_listening() -> void:
	_listen_peer = PacketPeerUDP.new()
	if _listen_peer.bind(BROADCAST_PORT) != OK:
		return
	_listening = true
	known_servers.clear()


## Stop broadcasting/listening.
func stop() -> void:
	_broadcasting = false
	_listening = false
	if _broadcast_peer:
		_broadcast_peer.close()
		_broadcast_peer = null
	if _listen_peer:
		_listen_peer.close()
		_listen_peer = null
	known_servers.clear()


func update_player_count(count: int) -> void:
	_player_count = count


func _process(delta: float) -> void:
	if _broadcasting:
		_broadcast_timer -= delta
		if _broadcast_timer <= 0:
			_send_broadcast()
			_broadcast_timer = BROADCAST_INTERVAL

	if _listening:
		_receive_broadcasts()
		_expire_servers()


func _send_broadcast() -> void:
	if _broadcast_peer == null:
		return
	var msg := "%s|%s|%d|%d" % [MAGIC, _host_name, _game_port, _player_count]
	_broadcast_peer.put_packet(msg.to_utf8_buffer())


func _receive_broadcasts() -> void:
	if _listen_peer == null:
		return
	while _listen_peer.get_available_packet_count() > 0:
		var data := _listen_peer.get_packet()
		var address := _listen_peer.get_packet_ip()
		var text := data.get_string_from_utf8()
		var parts := text.split("|")
		if parts.size() >= 4 and parts[0] == MAGIC:
			var host_name: String = parts[1]
			var port: int = int(parts[2])
			var players: int = int(parts[3])
			var is_new := address not in known_servers
			known_servers[address] = {
				"host_name": host_name,
				"port": port,
				"player_count": players,
				"last_seen": Time.get_ticks_msec() / 1000.0,
			}
			if is_new:
				server_found.emit(address, port, host_name, players)


func _expire_servers() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var expired: Array[String] = []
	for addr: String in known_servers:
		var info: Dictionary = known_servers[addr]
		if now - info["last_seen"] > TIMEOUT:
			expired.append(addr)
	for addr: String in expired:
		known_servers.erase(addr)
		server_lost.emit(addr)
