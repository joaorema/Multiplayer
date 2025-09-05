extends VoxelLodTerrain

@onready var voxel = %VoxelLodTerrain
@onready var player = %Player
func _ready():
	var player = $Player
	var voxel_terrain = %VoxelLodTerrain
	

func _on_player_shot_hit(position: Variant, collider: Variant) -> void:
	if player and player.has_weapon and player.current_weapon:
		var vt = voxel.get_voxel_tool()
		vt.mode = VoxelTool.MODE_REMOVE
		var hole = player.current_weapon.hole_size
		vt.do_sphere(position, hole)
	
