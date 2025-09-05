extends Node3D

var peer = ENetMultiplayerPeer.new()
@export var player_scene : PackedScene
@export var server_ip : String = "127.0.0.1"
@onready var server_label : Label = %Server_ip

# Add connection timeout
const CONNECTION_TIMEOUT = 15.0
var connection_timer: Timer
var is_connecting: bool = false
var is_hosting: bool = false

func _ready():
	# Create connection timer
	connection_timer = Timer.new()
	connection_timer.wait_time = CONNECTION_TIMEOUT
	connection_timer.timeout.connect(_on_connection_timeout)
	connection_timer.one_shot = true
	add_child(connection_timer)
	
	print("=== Network Debug Info ===")
	print("Godot version: ", Engine.get_version_info())
	print("Available IPs: ")
	for ip in IP.get_local_addresses():
		print("  ", ip)

# Clean up multiplayer on exit
func _exit_tree():
	disconnect_multiplayer()

# FIXED: Clean disconnect function without errors
func disconnect_multiplayer():
	print("Disconnecting multiplayer...")
	is_connecting = false
	is_hosting = false
	
	if connection_timer and connection_timer.is_inside_tree():
		connection_timer.stop()
	
	# Only disconnect signals if multiplayer peer exists and signals are connected
	if multiplayer.multiplayer_peer != null:
		if multiplayer.peer_connected.is_connected(add_player):
			multiplayer.peer_connected.disconnect(add_player)
		if multiplayer.peer_disconnected.is_connected(del_player):
			multiplayer.peer_disconnected.disconnect(del_player)
		if multiplayer.peer_connected.is_connected(_on_connected_to_server):
			multiplayer.peer_connected.disconnect(_on_connected_to_server)
		if multiplayer.peer_disconnected.is_connected(_on_disconnected_from_server):
			multiplayer.peer_disconnected.disconnect(_on_disconnected_from_server)
		if multiplayer.connection_failed.is_connected(_on_connection_failed):
			multiplayer.connection_failed.disconnect(_on_connection_failed)
	
	# Close peer first
	if peer:
		peer.close()
	
	# IMPORTANT: Set to null BEFORE creating new peer to avoid errors
	multiplayer.multiplayer_peer = null
	
	# Wait a frame before creating new peer
	await get_tree().process_frame
	
	# Create fresh peer
	peer = ENetMultiplayerPeer.new()
	print("Multiplayer disconnected cleanly")

func _on_host_pressed() -> void:
	if is_hosting or is_connecting:
		print("Already hosting or connecting, please wait...")
		return
		
	print("=== STARTING SERVER ===")
	await disconnect_multiplayer()  # Wait for clean disconnect
	
	# Create completely new peer
	peer = ENetMultiplayerPeer.new()
	is_hosting = true
	
	# FIXED: Use consistent port (7777)
	var error = peer.create_server(7777, 4)
	print("Server creation result: ", error)
	
	if error != OK:
		print("Failed to create server with error: ", error)
		match error:
			ERR_ALREADY_IN_USE:
				print("  Port 7777 is already in use!")
			ERR_CANT_CREATE:
				print("  Cannot create server - check permissions")
			_:
				print("  Unknown error: ", error)
		is_hosting = false
		return
	
	# Set up multiplayer
	multiplayer.multiplayer_peer = peer
	
	# Connect signals - check they aren't already connected
	if not multiplayer.peer_connected.is_connected(add_player):
		multiplayer.peer_connected.connect(add_player)
	if not multiplayer.peer_disconnected.is_connected(del_player):
		multiplayer.peer_disconnected.connect(del_player)
	
	# Wait a moment before adding host player
	await get_tree().process_frame
	
	# Add host player
	add_player(1)
	%Server_Ui.hide()
	
	var lan_ip = get_lan_ip()
	print("Server started successfully!")
	print("Server running on: ", lan_ip, ":7777")
	print("Server ID: ", multiplayer.get_unique_id())
	print("Is server: ", multiplayer.is_server())
	server_label.set_text(lan_ip + ":7777")

func _on_join_pressed() -> void:
	if is_hosting or is_connecting:
		print("Already hosting or connecting, please wait...")
		return
		
	if server_ip == "":
		print("Please enter a server IP address")
		return
	
	print("=== JOINING SERVER ===")
	print("Target server: ", server_ip, ":7777")
	await disconnect_multiplayer()  # Wait for clean disconnect
	
	# Create completely new peer
	peer = ENetMultiplayerPeer.new()
	is_connecting = true
	
	# Start connection timeout
	connection_timer.start()
	
	# FIXED: Use consistent port (7777)
	var error = peer.create_client(server_ip, 7777)
	print("Client creation result: ", error)
	
	if error != OK:
		print("Failed to create client with error: ", error)
		match error:
			ERR_INVALID_PARAMETER:
				print("  Invalid IP or port")
			ERR_CANT_CREATE:
				print("  Cannot create client")
			_:
				print("  Unknown error: ", error)
		connection_timer.stop()
		is_connecting = false
		return
	
	# Set up multiplayer
	multiplayer.multiplayer_peer = peer
	
	# Connect signals - check they aren't already connected
	if not multiplayer.peer_connected.is_connected(_on_connected_to_server):
		multiplayer.peer_connected.connect(_on_connected_to_server)
	if not multiplayer.peer_disconnected.is_connected(_on_disconnected_from_server):
		multiplayer.peer_disconnected.connect(_on_disconnected_from_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	
	%Server_Ui.hide()
	print("Client created, attempting connection...")

# Connection timeout handler
func _on_connection_timeout():
	print("=== CONNECTION TIMEOUT ===")
	print("Failed to connect after ", CONNECTION_TIMEOUT, " seconds")
	_on_connection_failed()

# Connection event handlers
func _on_connected_to_server():
	print("=== CONNECTION SUCCESS ===")
	print("Successfully connected to server!")
	if multiplayer.multiplayer_peer != null:
		print("My ID: ", multiplayer.get_unique_id())
		print("Is server: ", multiplayer.is_server())
	connection_timer.stop()
	is_connecting = false

func _on_disconnected_from_server():
	print("=== DISCONNECTED FROM SERVER ===")
	connection_timer.stop()
	is_connecting = false
	%Server_Ui.show()
	# Don't immediately disconnect - might be temporary
	await get_tree().create_timer(2.0).timeout
	disconnect_multiplayer()

func _on_connection_failed():
	print("=== CONNECTION FAILED ===")
	print("Failed to connect to server: ", server_ip, ":7777")
	connection_timer.stop()
	is_connecting = false
	%Server_Ui.show()
	disconnect_multiplayer()

# IMPROVED: Player management with better error handling
func add_player(id = 1):
	print("=== ADDING PLAYER ===")
	print("Player ID: ", id)
	
	# Check if player already exists
	if has_node(str(id)):
		print("Player with ID ", id, " already exists, skipping")
		return
	
	# Check if we have a valid scene
	if not player_scene:
		print("ERROR: player_scene is not assigned!")
		return
	
	# Check if we're in a valid state to add players
	if multiplayer.multiplayer_peer == null:
		print("ERROR: No multiplayer peer, cannot add player")
		return
	
	var player = player_scene.instantiate()
	if not player:
		print("ERROR: Failed to instantiate player scene!")
		return
		
	player.name = str(id)
	
	# Add player on next frame to ensure everything is ready
	call_deferred("add_child", player)
	print("Player successfully scheduled for addition with ID: ", id)

func del_player(id):
	print("=== REMOVING PLAYER ===")
	print("Player ID: ", id)
	
	# Use call_local to avoid RPC issues during disconnection
	_del_player(id)
	
	# Only send RPC if we have a valid connection
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		rpc("_del_player", id)

@rpc("any_peer", "call_local", "reliable")
func _del_player(id):
	var player_node = get_node_or_null(str(id))
	if player_node:
		player_node.queue_free()
		print("Player ", id, " removed")
	else:
		print("Player ", id, " not found for removal")

# Enhanced LAN IP detection - prioritize real network adapters
func get_lan_ip() -> String:
	var addresses = IP.get_local_addresses()
	print("All detected IP addresses:")
	for addr in addresses:
		print("  ", addr)
	
	# Look for actual LAN IPs, prioritizing real network adapters
	var lan_ips = []
	
	for ip in addresses:
		if ip.begins_with("192.168.1."):  # Most common home router range
			lan_ips.append(ip)
		elif ip.begins_with("192.168.0."):  # Second most common
			lan_ips.append(ip)
		elif ip.begins_with("10."):
			lan_ips.append(ip)
		elif ip.begins_with("192.168.") and not ip.begins_with("192.168.56."):  # Skip VirtualBox
			lan_ips.append(ip)
	
	# Return the first real LAN IP found
	if lan_ips.size() > 0:
		print("Using LAN IP: ", lan_ips[0])
		return lan_ips[0]
	
	# Fallback to any 192.168.x.x if no preferred found
	for ip in addresses:
		if ip.begins_with("192.168."):
			print("Using fallback LAN IP: ", ip)
			return ip
	
	print("No LAN IP found, using localhost")
	return "127.0.0.1"

# Function to set server IP (called from UI)
func set_server_ip(ip: String):
	server_ip = ip.strip_edges()
	print("Server IP set to: ", server_ip)

# ADDED: Monitor connection health
func _process(_delta):
	# Monitor connection state for debugging
	if is_connecting and multiplayer.multiplayer_peer:
		var state = multiplayer.multiplayer_peer.get_connection_status()
		if state == MultiplayerPeer.CONNECTION_CONNECTED:
			print("Connection established!")
			is_connecting = false
		elif state == MultiplayerPeer.CONNECTION_DISCONNECTED:
			print("Connection lost during connecting phase")
			_on_connection_failed()
