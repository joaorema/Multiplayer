# ak47.gd
extends Weapon

func _ready():
	super._ready() # call parent setup
	
	
	
	# Set specific stats for AK-47
	weapon_name = "SHOTGUN"
	weapon_type = "shotgun"
	max_ammo = 4
	current_ammo = 4
	reload_time = 2.0
	weapon_range = 100.0
	damage = 30
	fire_rate = 0.50
	ads_fov = 35.0
	hole_size = 0.9  # Small holes for assault rifle
	
	# Override mesh and collision if needed
	mesh_instance = %shotgun
	collision_shape = %shotgun_collison
	shoot_anim = %Shotgun_anim
