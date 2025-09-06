# GameWorld.gd - Attach this to your main game scene root node
extends Node

@onready var terrain: VoxelTerrain = $VoxelTerrain
@onready var terrain_sync: VoxelTerrainMultiplayerSynchronizer = $VoxelTerrain/VoxelTerrainMultiplayerSynchronizer
@onready var players_container: Node = $Players

# Store viewers for each player
var player_viewers: Dictionary = {}

func _ready():
	# Add terrain to group for easy access
	terrain.add_to_group("terrain")
	
	# Configure based on whether this is server or client
	if multiplayer.is_server():
		setup_as_server()
	else:
		setup_as_client()

# ============= SERVER SETUP =============
func setup_as_server():
	print("🖥️ Setting up terrain as SERVER")
	
	# Server terrain configuration
	terrain.automatic_loading_enabled = true
	terrain.block_enter_notification_enabled = true
	terrain.area_edit_notification_enabled = true
	
	# Connect multiplayer signals
	multiplayer.peer_connected.connect(_on_player_joined)
	multiplayer.peer_disconnected.connect(_on_player_left)
	
	print("✅ Server terrain setup complete")

func _on_player_joined(peer_id: int):
	print("👤 Player joined: ", peer_id, " - Creating viewer")
	
	# Create a VoxelViewer for the new player
	var viewer = VoxelViewer.new()
	viewer.name = "Viewer_" + str(peer_id)
	# Don't set network_peer_id - it doesn't exist in this version
	viewer.view_distance = 100
	
	terrain.add_child(viewer)
	player_viewers[peer_id] = viewer
	
	# Position viewer at player spawn location
	var spawn_pos = get_player_spawn_position(peer_id)
	viewer.global_position = spawn_pos
	
	print("✅ Viewer created for player ", peer_id, " at ", spawn_pos)

func _on_player_left(peer_id: int):
	print("👋 Player left: ", peer_id, " - Removing viewer")
	
	if peer_id in player_viewers:
		var viewer = player_viewers[peer_id]
		if viewer:
			viewer.queue_free()
		player_viewers.erase(peer_id)
		print("✅ Viewer removed for player ", peer_id)

# ============= CLIENT SETUP =============
func setup_as_client():
	print("💻 Setting up terrain as CLIENT")
	
	# Client terrain configuration
	terrain.automatic_loading_enabled = false  # Server will send terrain data
	terrain.block_enter_notification_enabled = false
	terrain.area_edit_notification_enabled = false
	
	# Create viewer for local player only
	create_local_viewer()
	
	print("✅ Client terrain setup complete")

func create_local_viewer():
	var my_peer_id = multiplayer.get_unique_id()
	print("🎮 Creating local viewer for peer: ", my_peer_id)
	
	var viewer = VoxelViewer.new()
	viewer.name = "LocalViewer"
	# Don't set network_peer_id - it doesn't exist in this version
	viewer.view_distance = 120  # Slightly larger than server to prevent holes
	
	terrain.add_child(viewer)
	player_viewers[my_peer_id] = viewer
	
	# Position will be updated by player movement
	update_local_viewer_position()
	
	print("✅ Local viewer created")

# ============= SHARED FUNCTIONS =============
func update_local_viewer_position():
	# Find the local player and update viewer position
	var local_player = get_local_player()
	if local_player:
		var my_peer_id = multiplayer.get_unique_id()
		if my_peer_id in player_viewers:
			var viewer = player_viewers[my_peer_id]
			if viewer:
				viewer.global_position = local_player.global_position

func get_local_player():
	# Find the player that belongs to this client
	var players = get_tree().get_nodes_in_group("PlayerCharacter")
	for player in players:
		if player.get_multiplayer_authority() == multiplayer.get_unique_id():
			return player
	return null

func get_player_spawn_position(peer_id: int) -> Vector3:
	# TODO: Implement your spawn logic here
	# For now, return a default spawn position
	return Vector3(0, 10, 0)

# Called by players when they move (for server to update their viewers)
func update_player_viewer_position(peer_id: int, position: Vector3):
	if not multiplayer.is_server():
		return
		
	if peer_id in player_viewers:
		var viewer = player_viewers[peer_id]
		if viewer:
			viewer.global_position = position
