# ak47.gd
extends Weapon

func _ready():
	super._ready() # call parent setup
	
	# Set specific stats for AK-47
	weapon_name = "AK-47"
	weapon_type = "assault_rifle"
	max_ammo = 30
	current_ammo = 30
	reload_time = 2.0
	weapon_range = 100.0
	damage = 30
	fire_rate = 0.25
	ads_fov = 35.0
	hole_size = 1.2  # Small holes for assault rifle
	
	# Override mesh and collision if needed
	mesh_instance = $ak47 
	collision_shape = $CollisionShape3D
	shoot_anim = %ak_shoot
