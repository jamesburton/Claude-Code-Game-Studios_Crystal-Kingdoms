## Network lobby screen — host or join a LAN game.
class_name LobbyScreen
extends Control

signal back_pressed()
signal match_ready(server: GameServer, config: GameConfig)
signal client_match_starting(client: GameClient, config_data: Dictionary)

var _server: GameServer
var _client: GameClient
var _discovery: LanDiscovery
var _player_list_label: Label
var _status_label: Label
var _host_panel: Control
var _join_panel: Control
var _lobby_panel: Control
var _lan_games_list: VBoxContainer


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.12)
	add_child(bg)

	var vp := get_viewport().get_visible_rect().size
	var center_x := vp.x / 2

	# Title
	var title := Label.new()
	title.text = "LAN Multiplayer"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
	title.position = Vector2(center_x - 200, 40)
	title.size = Vector2(400, 40)
	add_child(title)

	# Host / Join buttons
	_host_panel = Control.new()
	add_child(_host_panel)

	var host_btn := Button.new()
	host_btn.text = "Host Game"
	host_btn.custom_minimum_size = Vector2(200, 50)
	host_btn.add_theme_font_size_override("font_size", 22)
	host_btn.position = Vector2(center_x - 220, vp.y / 2 - 40)
	host_btn.pressed.connect(_start_hosting)
	_host_panel.add_child(host_btn)

	var join_btn := Button.new()
	join_btn.text = "Join Game"
	join_btn.custom_minimum_size = Vector2(200, 50)
	join_btn.add_theme_font_size_override("font_size", 22)
	join_btn.position = Vector2(center_x + 20, vp.y / 2 - 40)
	join_btn.pressed.connect(_show_join_panel)
	_host_panel.add_child(join_btn)

	# Join panel (hidden initially)
	_join_panel = Control.new()
	_join_panel.visible = false
	add_child(_join_panel)

	var ip_label := Label.new()
	ip_label.text = "Server IP:"
	ip_label.add_theme_font_size_override("font_size", 18)
	ip_label.position = Vector2(center_x - 180, vp.y / 2 - 20)
	_join_panel.add_child(ip_label)

	var ip_edit := LineEdit.new()
	ip_edit.placeholder_text = "192.168.1.x or localhost"
	ip_edit.text = "localhost"
	ip_edit.custom_minimum_size = Vector2(250, 35)
	ip_edit.position = Vector2(center_x - 50, vp.y / 2 - 25)
	_join_panel.add_child(ip_edit)

	var connect_btn := Button.new()
	connect_btn.text = "Connect"
	connect_btn.custom_minimum_size = Vector2(120, 35)
	connect_btn.position = Vector2(center_x - 60, vp.y / 2 + 20)
	connect_btn.pressed.connect(func() -> void: _connect_to(ip_edit.text))
	_join_panel.add_child(connect_btn)

	# LAN games list
	var lan_header := Label.new()
	lan_header.text = "LAN Games Found:"
	lan_header.add_theme_font_size_override("font_size", 16)
	lan_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	lan_header.position = Vector2(center_x - 180, vp.y / 2 + 70)
	_join_panel.add_child(lan_header)

	_lan_games_list = VBoxContainer.new()
	_lan_games_list.position = Vector2(center_x - 180, vp.y / 2 + 95)
	_join_panel.add_child(_lan_games_list)

	# Lobby panel (shown after hosting or joining)
	_lobby_panel = Control.new()
	_lobby_panel.visible = false
	add_child(_lobby_panel)

	_player_list_label = Label.new()
	_player_list_label.position = Vector2(center_x - 150, 120)
	_player_list_label.size = Vector2(300, 300)
	_player_list_label.add_theme_font_size_override("font_size", 18)
	_player_list_label.add_theme_color_override("font_color", Color.WHITE)
	_lobby_panel.add_child(_player_list_label)

	_status_label = Label.new()
	_status_label.position = Vector2(center_x - 150, vp.y - 80)
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_lobby_panel.add_child(_status_label)

	var start_btn := Button.new()
	start_btn.text = "Start Match"
	start_btn.custom_minimum_size = Vector2(200, 45)
	start_btn.add_theme_font_size_override("font_size", 20)
	start_btn.position = Vector2(center_x - 100, vp.y - 130)
	start_btn.pressed.connect(_on_start_match)
	_lobby_panel.add_child(start_btn)

	# Back button
	var back := Button.new()
	back.text = "Back"
	back.position = Vector2(20, 20)
	back.custom_minimum_size = Vector2(80, 35)
	back.pressed.connect(func() -> void:
		_cleanup()
		back_pressed.emit())
	add_child(back)


func _start_hosting() -> void:
	_server = GameServer.new()
	add_child(_server)
	var err := _server.start(19735, "Host")
	if err != OK:
		_status_label.text = "Failed to start server: %s" % error_string(err)
		return

	_server.lobby_updated.connect(_update_lobby_display)
	_host_panel.visible = false
	_lobby_panel.visible = true

	# Get local IP for display
	var ips := IP.get_local_addresses()
	var display_ip := "localhost"
	for ip: String in ips:
		if ip.begins_with("192.168") or ip.begins_with("10.") or ip.begins_with("172."):
			display_ip = ip
			break

	_status_label.text = "Hosting on %s:%d — share this with other players" % [display_ip, 19735]
	_update_lobby_display()

	# Start broadcasting for LAN discovery
	_discovery = LanDiscovery.new()
	add_child(_discovery)
	_discovery.start_broadcasting(host_name, 19735, 1)
	_server.lobby_updated.connect(func() -> void:
		if _discovery: _discovery.update_player_count(_server.get_player_count()))


func _show_join_panel() -> void:
	_host_panel.visible = false
	_join_panel.visible = true
	# Start LAN discovery
	_discovery = LanDiscovery.new()
	add_child(_discovery)
	_discovery.start_listening()
	_discovery.server_found.connect(_on_lan_server_found)


func _connect_to(address: String) -> void:
	_client = GameClient.new()
	add_child(_client)
	_client.lobby_updated.connect(func(players: Array, host: String) -> void:
		_update_client_lobby(players, host))
	_client.error_received.connect(func(msg: String) -> void:
		_status_label.text = "Error: %s" % msg)
	_client.connected_to_server.connect(func() -> void:
		_join_panel.visible = false
		_lobby_panel.visible = true
		_status_label.text = "Connected to %s" % address)
	_client.match_starting.connect(func(config_data: Dictionary) -> void:
		client_match_starting.emit(_client, config_data))

	var err := _client.connect_to_server(address, 19735, "Player")
	if err != OK:
		_status_label.text = "Failed to connect: %s" % error_string(err)


func _update_lobby_display() -> void:
	if _server == null:
		return
	var text := "Players in room:\n\n"
	for pid: int in _server.players:
		var p: Dictionary = _server.players[pid]
		text += "  %d. %s\n" % [p["slot"] + 1, p["name"]]
	_player_list_label.text = text


func _update_client_lobby(players: Array, host: String) -> void:
	var text := "Host: %s\nPlayers:\n\n" % host
	for p: Dictionary in players:
		text += "  %d. %s\n" % [p.get("slot", 0) + 1, p.get("name", "?")]
	_player_list_label.text = text


func _on_start_match() -> void:
	if _server:
		# Load saved settings or use defaults
		var config := SettingsManager.load_config()
		if config == null:
			config = GameConfig.new()
		config.player_count = _server.get_player_count()
		match_ready.emit(_server, config)


func _on_lan_server_found(address: String, port: int, host_name: String, player_count: int) -> void:
	if _lan_games_list == null:
		return
	# Check if already listed
	for child in _lan_games_list.get_children():
		if child.has_meta("address") and child.get_meta("address") == address:
			return  # Already listed

	var row := HBoxContainer.new()
	row.set_meta("address", address)
	row.custom_minimum_size.y = 30

	var info := Label.new()
	info.text = "%s (%s:%d) — %d players" % [host_name, address, port, player_count]
	info.add_theme_font_size_override("font_size", 14)
	info.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var join_btn := Button.new()
	join_btn.text = "Join"
	join_btn.custom_minimum_size = Vector2(60, 28)
	join_btn.pressed.connect(func() -> void: _connect_to(address))
	row.add_child(join_btn)

	_lan_games_list.add_child(row)


func _cleanup() -> void:
	if _discovery:
		_discovery.stop()
		_discovery.queue_free()
		_discovery = null
	if _server:
		_server.stop()
		_server.queue_free()
		_server = null
	if _client:
		_client.disconnect_from_server()
		_client.queue_free()
		_client = null
