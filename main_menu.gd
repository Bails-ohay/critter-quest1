extends Control

const PORT := 7777
const MAX_PLAYERS := 10

@onready var button_list: VBoxContainer = $ButtonList
@onready var join_panel: Panel = $JoinPanel
@onready var options_panel: Panel = $OptionsPanel
@onready var ip_input: LineEdit = $JoinPanel/VBoxContainer/IPInput
@onready var status_label: Label = $StatusLabel


func _ready() -> void:
	$ButtonList/SinglePlayerButton.pressed.connect(_on_single_player_pressed)
	$ButtonList/HostButton.pressed.connect(_on_host_pressed)
	$ButtonList/JoinButton.pressed.connect(_on_join_pressed)
	$ButtonList/OptionsButton.pressed.connect(_on_options_pressed)
	$JoinPanel/VBoxContainer/ConnectButton.pressed.connect(_on_connect_pressed)
	$JoinPanel/VBoxContainer/JoinBackButton.pressed.connect(_on_back_pressed)
	$OptionsPanel/VBoxContainer/OptionsBackButton.pressed.connect(_on_back_pressed)

	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

	join_panel.visible = false
	options_panel.visible = false
	status_label.text = ""


func _on_single_player_pressed() -> void:
	SceneManager.go_to_scene("res://main.tscn")


func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_PLAYERS)
	if error != OK:
		status_label.text = "Failed to start server."
		return
	multiplayer.multiplayer_peer = peer
	_attempt_upnp()
	status_label.text = "Hosting on port %d" % PORT
	SceneManager.go_to_scene("res://main.tscn")


func _on_join_pressed() -> void:
	button_list.visible = false
	join_panel.visible = true


func _on_connect_pressed() -> void:
	var ip := ip_input.text.strip_edges()
	if ip == "":
		status_label.text = "Enter an IP address first."
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ip, PORT)
	if error != OK:
		status_label.text = "Could not start connection."
		return
	multiplayer.multiplayer_peer = peer
	status_label.text = "Connecting..."


func _on_connected_to_server() -> void:
	status_label.text = "Connected!"
	SceneManager.go_to_scene("res://main.tscn")


func _on_connection_failed() -> void:
	status_label.text = "Connection failed. Check the IP and try again."
	multiplayer.multiplayer_peer = null


func _on_options_pressed() -> void:
	button_list.visible = false
	options_panel.visible = true


func _on_back_pressed() -> void:
	join_panel.visible = false
	options_panel.visible = false
	button_list.visible = true
	status_label.text = ""


func _attempt_upnp() -> void:
	var upnp := UPNP.new()
	var discover_result := upnp.discover()
	if discover_result == UPNP.UPNP_RESULT_SUCCESS and upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
		upnp.add_port_mapping(PORT, PORT, "CritterQuest", "UDP")
		print("UPnP: port forwarded automatically.")
	else:
		print("UPnP failed — friends outside your network may need you to forward port ", PORT, " manually.")
