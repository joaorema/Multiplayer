# awp.gd
extends Weapon

func _ready():
	super._ready() # call parent setup
	
	# Set specific stats for AWP sniper
	weapon_name = "SMG"
	weapon_type = "semi_automatic"  # Make sure this matches your player script
	max_ammo = 35
	current_ammo = 35
	reload_time = 1.5
	weapon_range = 75.0
	damage = 15
	fire_rate = 0.1
	ads_fov = 15.0
	hole_size = 0.8
	
	mesh_instance = %mac10 if has_node("mac10") else mesh_instance
	collision_shape = $CollisionShape3D
