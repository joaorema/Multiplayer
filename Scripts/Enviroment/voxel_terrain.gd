# VoxelTerrain script with manual synchronization
extends VoxelTerrain

func _ready():
	add_to_group("Dirt")
	connect_to_existing_players()
	get_tree().node_added.connect(_on_node_added)

func connect_to_existing_players():
	var players = get_tree().get_nodes_in_group("PlayerCharacter")
	for player in players:
		connect_to_player(player)

func _on_node_added(node):
	if node.is_in_group("PlayerCharacter"):
		connect_to_player(node)

func connect_to_player(player):
	if not player.shot_hit.is_connected(_on_player_shot_hit):
		player.shot_hit.connect(_on_player_shot_hit)
		print("Connected to player: ", player.name)
		
	if not player.punch_hit.is_connected(_on_player_punch_hit):
		player.punch_hit.connect(_on_player_punch_hit)
		print("Connected to player punches: ", player.name)

func _on_player_punch_hit(position: Vector3, collider: Node) -> void:
	if collider == null or collider == self:
		print("Player punch hit terrain at: ", position, " | Is Server: ", multiplayer.is_server())
		
		if multiplayer.is_server():
			# Server directly processes punch
			modify_terrain_and_sync(position, 1.5, "punch")  # Small hole size for punch
		else:
			# Client requests punch terrain modification
			print("Client requesting punch terrain modification at: ", position)
			request_terrain_modification.rpc_id(1, position, 1.5, "punch")

func _on_player_shot_hit(position: Vector3, collider: Node, hole_size: float, weapon_type: String) -> void:
	if collider == null or collider == self:
		print("Player shot hit terrain at: ", position, " | Is Server: ", multiplayer.is_server(), " | Weapon: ", weapon_type)
		
		if multiplayer.is_server():
			# Server directly processes and syncs
			modify_terrain_and_sync(position, hole_size, weapon_type)
		else:
			# Client requests terrain modification from server
			print("Client requesting terrain modification at: ", position, " with weapon: ", weapon_type)
			request_terrain_modification.rpc_id(1, position, hole_size, weapon_type)

# RPC function for clients to request terrain modification from server
@rpc("any_peer", "call_remote", "reliable")
func request_terrain_modification(world_position: Vector3, hole_size: float, weapon_type: String):
	# Only server processes these requests
	if multiplayer.is_server():
		print("Server received terrain modification request from client at: ", world_position, " with weapon: ", weapon_type)
		modify_terrain_and_sync(world_position, hole_size, weapon_type)

# Server function - modifies terrain and tells all clients to do the same
func modify_terrain_and_sync(world_position: Vector3, hole_size: float, weapon_type: String):
	print("Server modifying terrain at: ", world_position, " with weapon: ", weapon_type)
	modify_terrain_at_position(world_position, hole_size, weapon_type)
	# Tell all clients to modify the same spot
	modify_terrain_rpc.rpc(world_position, hole_size, weapon_type)

# RPC function that all clients (including server) will execute
@rpc("authority", "call_local", "reliable")
func modify_terrain_rpc(world_position: Vector3, hole_size: float, weapon_type: String):
	if not multiplayer.is_server():  # Only clients execute this, server already did it
		print("Client executing terrain modification at: ", world_position, " with weapon: ", weapon_type)
		modify_terrain_at_position(world_position, hole_size, weapon_type)

func modify_terrain_at_position(world_position: Vector3, hole_size: float, weapon_type: String):
	var vt = get_voxel_tool()
	
	# Check weapon type to determine what action to take
	match weapon_type.to_lower():
		"paint", "constructor", "build_gun":  # Building weapons
			print("Building terrain at: ", world_position, " with size: ", hole_size)
			vt.mode = VoxelTool.MODE_ADD
			vt.do_sphere(world_position, hole_size)
			print("Terrain built")
		"punch":  # Special case for punching
			print("Punching terrain at: ", world_position, " with size: ", hole_size)
			vt.mode = VoxelTool.MODE_REMOVE
			vt.do_sphere(world_position, hole_size * 0.7)  # Smaller punch holes
			print("Terrain punched")
		_:  # Default case - all other weapons destroy terrain
			print("Destroying terrain at: ", world_position, " with size: ", hole_size)
			vt.mode = VoxelTool.MODE_REMOVE
			vt.do_sphere(world_position, hole_size)
			print("Terrain destroyed")
