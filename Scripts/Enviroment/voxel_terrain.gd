extends VoxelLodTerrain

@onready var voxel = %VoxelLodTerrain
@onready var player = %Player
func _ready():
	var player = $Player
	var voxel_terrain = %VoxelLodTerrain
	

func _on_player_shot_hit(position: Vector3, collider: Node, hole_size: float) -> void:
	# Only destroy terrain if we hit the terrain or if there's no collider (missed shot)
	if collider == null or collider == self:
		destroy_terrain_at_position(position, hole_size)

func destroy_terrain_at_position(world_position: Vector3, hole_size: float):
	var vt = get_voxel_tool()
	vt.mode = VoxelTool.MODE_REMOVE
	vt.do_sphere(world_position, hole_size)
	print("Destroyed terrain at: ", world_position, " with hole size: ", hole_size)
	
