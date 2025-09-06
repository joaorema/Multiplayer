# awp.gd
extends Weapon

func _ready():
	super._ready() # call parent setup
	
	# Set specific stats for AWP sniper
	weapon_name = "AWP"
	weapon_type = "sniper"  # Make sure this matches your player script
	max_ammo = 1
	current_ammo = 1
	reload_time = 3.0
	weapon_range = 200.0
	damage = 100
	fire_rate = 0.3
	ads_fov = 15.0
	hole_size = 2.0
	
	mesh_instance = %awp if has_node("awp") else mesh_instance
	collision_shape = $CollisionShape3D
	
