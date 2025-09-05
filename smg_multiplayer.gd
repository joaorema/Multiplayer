# awp.gd
extends Weapon

func _ready():
	super._ready() # call parent setup
	
	# Set specific stats for AWP sniper
	weapon_name = "SMG"
	weapon_type = "semi_automatic"  # Make sure this matches your player script
	max_ammo = 35
	current_ammo = 35
	reload_time = 1
	weapon_range = 150.0
	damage = 15
	fire_rate = 0.1
	ads_fov = 15.0
	
	# Override mesh and collision if needed
	# Try these approaches:
	if has_node("mac10"):
		mesh_instance = %mac10
	elif has_node("%mac10"):
		mesh_instance = %mac10
	# Keep the original mesh_instance if neither exists
	
	collision_shape = %CollisionShape3D
