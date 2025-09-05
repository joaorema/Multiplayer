# ak47.gd
extends Weapon

func _ready():
	super._ready() # call parent setup
	
	# Set specific stats for AK-47
	weapon_name = "AK-47"
	weapon_type = "assault_rifle"
	max_ammo = 30
	current_ammo = 30
	reload_time = 2.5
	weapon_range = 150.0
	damage = 30
	fire_rate = 0.1
	ads_fov = 35.0
	hole_size = 1.5  # Small holes for assault rifle
	
	# Override mesh and collision if needed
	mesh_instance = $ak47 if has_node("ak47") else mesh_instance
	collision_shape = $CollisionShape3D
