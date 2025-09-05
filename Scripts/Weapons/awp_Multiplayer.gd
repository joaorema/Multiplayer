# awp.gd
extends Weapon

func _ready():
	super._ready() # call parent setup
	
	# Set specific stats for AWP sniper
	weapon_name = "AWP"
	weapon_type = "sniper"  # Make sure this matches your player script
	max_ammo = 1
	current_ammo = 1
	reload_time = 2.5
	weapon_range = 300.0
	damage = 100
	fire_rate = 0.5
	ads_fov = 15.0
	
	# Override mesh and collision if needed
	# Try these approaches:
	if has_node("awp"):
		mesh_instance = $awp
	elif has_node("%awp"):
		mesh_instance = %awp
	# Keep the original mesh_instance if neither exists
	
	collision_shape = %CollisionShape3D
	
