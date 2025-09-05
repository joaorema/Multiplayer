extends Node3D

# MultiplayerManager.gd - Attach this to a separate Node (not the world)

var peer = ENetMultiplayerPeer.new()
@export var player_scene : PackedScene
@export var server_ip : String = "127.0.0.1"
@onready var Player_name : LineEdit = %Player_Name
var chosen_name: String = "Player"  # default fallback


# Reference to UI and world
var ui_node: Control
var world_node: Node3D

const CONNECTION_TIMEOUT = 15.0
var connection_timer: Timer
var is_connecting: bool = false
var is_hosting: bool = false

func _ready():
	# Find UI and world nodes
	ui_node = get_node("../ServerUI")  # Adjust path as needed
	world_node = get_node("../")  # Adjust path as needed
	
	connection_timer = Timer.new()
	connection_timer.wait_time = CONNECTION_TIMEOUT
	connection_timer.timeout.connect(_on_connection_timeout)
	connection_timer.one_shot = true
	add_child(connection_timer)
	
	print("=== Multiplayer Manager Ready ===")

func _exit_tree():
	disconnect_multiplayer()

func disconnect_multiplayer():
	print("Disconnecting multiplayer...")
	is_connecting = false
	is_hosting = false
	
	if connection_timer:
		connection_timer.stop()
	
	# Clean disconnect signals
	if multiplayer.multiplayer_peer != null:
		_disconnect_all_signals()
	
	if peer:
		peer.close()
	
	multiplayer.multiplayer_peer = null
	await get_tree().process_frame
	peer = ENetMultiplayerPeer.new()
	print("Multiplayer disconnected cleanly")

func _disconnect_all_signals():
	var signals_to_disconnect = [
		[multiplayer.peer_connected, add_player],
		[multiplayer.peer_disconnected, del_player],
		[multiplayer.peer_connected, _on_connected_to_server],
		[multiplayer.peer_disconnected, _on_disconnected_from_server],
		[multiplayer.connection_failed, _on_connection_failed]
	]
	
	for signal_pair in signals_to_disconnect:
		if signal_pair[0].is_connected(signal_pair[1]):
			signal_pair[0].disconnect(signal_pair[1])

func start_server():
	if is_hosting or is_connecting:
		print("Already hosting or connecting")
		return false
		
	print("=== STARTING SERVER ===")
	await disconnect_multiplayer()
	
	peer = ENetMultiplayerPeer.new()
	is_hosting = true
	
	var error = peer.create_server(7777, 4)
	if error != OK:
		print("Failed to create server: ", error)
		is_hosting = false
		return false
	
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(del_player)
	
	await get_tree().process_frame
	add_player(1)  # Add host
	
	print("Server started on: ", get_lan_ip(), ":7777")
	return true

func join_server(ip: String):
	if is_hosting or is_connecting:
		print("Already hosting or connecting")
		return false
		
	if ip == "":
		print("No IP provided")
		return false
	
	print("=== JOINING SERVER: ", ip, " ===")
	await disconnect_multiplayer()
	
	peer = ENetMultiplayerPeer.new()
	is_connecting = true
	connection_timer.start()
	
	var error = peer.create_client(ip, 7777)
	if error != OK:
		print("Failed to create client: ", error)
		is_connecting = false
		connection_timer.stop()
		return false
	
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_connected_to_server)
	multiplayer.peer_disconnected.connect(_on_disconnected_from_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	print("Client created, connecting...")
	return true

func _on_connection_timeout():
	print("Connection timeout")
	_on_connection_failed()

func _on_connected_to_server(peer_id: int = 0):
	print("=== CONNECTED TO SERVER ===")
	print("My ID: ", multiplayer.get_unique_id())
	connection_timer.stop()
	is_connecting = false

func _on_disconnected_from_server(peer_id: int = 0):
	print("=== DISCONNECTED FROM SERVER ===")
	connection_timer.stop()
	is_connecting = false

func _on_connection_failed():
	print("=== CONNECTION FAILED ===")
	connection_timer.stop()
	is_connecting = false
	disconnect_multiplayer()

# Player management - spawn in world node
func add_player(id: int):
	print("Adding player: ", id)
	
	if world_node.has_node(str(id)):
		print("Player already exists")
		return
	
	if not player_scene:
		print("No player scene assigned")
		return
	
	var player = player_scene.instantiate()
	player.name = str(id)
	world_node.call_deferred("add_child", player)

func del_player(id: int):
	print("Removing player: ", id)
	_del_player(id)
	
	if multiplayer.multiplayer_peer != null:
		rpc("_del_player", id)

@rpc("any_peer", "call_local", "reliable")
func _del_player(id: int):
	var player = world_node.get_node_or_null(str(id))
	if player:
		player.queue_free()

func get_lan_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.1."):
			return ip
		elif ip.begins_with("192.168.0."):
			return ip
	
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") and not ip.begins_with("192.168.56."):
			return ip
			
	return "127.0.0.1"





func _on_player_name_text_submitted(new_text: String) -> void:
	if new_text.strip_edges() != "":
		chosen_name = new_text
		print(chosen_name)
