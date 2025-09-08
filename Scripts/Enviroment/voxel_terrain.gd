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
		
		
	if not player.punch_hit.is_connected(_on_player_punch_hit):
		player.punch_hit.connect(_on_player_punch_hit)
		

func _on_player_punch_hit(position: Vector3, collider: Node) -> void:
	if collider == null or collider == self:
		
		
		if multiplayer.is_server():
			# Server directly processes punch
			modify_terrain_and_sync(position, 1.5, "punch")  # Small hole size for punch
		else:
			# Client requests punch terrain modification
			request_terrain_modification.rpc_id(1, position, 1.5, "punch")

func _on_player_shot_hit(position: Vector3, collider: Node, hole_size: float, weapon_type: String) -> void:
	if collider == null or collider == self:
		
		
		if multiplayer.is_server():
			# Server directly processes and syncs
			modify_terrain_and_sync(position, hole_size, weapon_type)
		else:
			# Client requests terrain modification from server
			
			request_terrain_modification.rpc_id(1, position, hole_size, weapon_type)

# RPC function for clients to request terrain modification from server
@rpc("any_peer", "call_remote", "reliable")
func request_terrain_modification(world_position: Vector3, hole_size: float, weapon_type: String):
	# Only server processes these requests
	if multiplayer.is_server():
		
		modify_terrain_and_sync(world_position, hole_size, weapon_type)

# Server function - modifies terrain and tells all clients to do the same
func modify_terrain_and_sync(world_position: Vector3, hole_size: float, weapon_type: String):
	
	modify_terrain_at_position(world_position, hole_size, weapon_type)
	# Tell all clients to modify the same spot
	modify_terrain_rpc.rpc(world_position, hole_size, weapon_type)

# RPC function that all clients (including server) will execute
@rpc("authority", "call_local", "reliable")
func modify_terrain_rpc(world_position: Vector3, hole_size: float, weapon_type: String):
	if not multiplayer.is_server():  # Only clients execute this, server already did it
		
		modify_terrain_at_position(world_position, hole_size, weapon_type)

func modify_terrain_at_position(world_position: Vector3, hole_size: float, weapon_type: String):
	var vt = get_voxel_tool()
	
	match weapon_type.to_lower():
		"paint", "constructor", "build_gun":
			# Building weapons place material
			vt.mode = VoxelTool.MODE_ADD
			vt.do_sphere(world_position, hole_size)

		"punch":
			# Punch is a smaller remove action
			vt.mode = VoxelTool.MODE_REMOVE
			vt.do_sphere(world_position, hole_size * 0.7)
			

		"shotgun":
			# Shotgun creates multiple small holes for pellets
			vt.mode = VoxelTool.MODE_REMOVE
			var pellet_count := 6
			var pellet_spread := 0.5 # adjust for wider/lighter terrain impact
			for i in range(pellet_count):
				var offset := Vector3(
					randf_range(-pellet_spread, pellet_spread),
					randf_range(-pellet_spread, pellet_spread),
					randf_range(-pellet_spread, pellet_spread)
				)
				vt.do_sphere(world_position + offset, hole_size * 0.5)
				#print(world_position + offset, hole_size * 0.5)

		_:
			# Default - most weapons just remove normally
			vt.mode = VoxelTool.MODE_REMOVE
			vt.do_sphere(world_position, hole_size)

			
