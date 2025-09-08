extends Weapon

func _ready():
	super._ready() # call parent setup
	
	# Set specific stats for AK-47
	weapon_name = "PAINT"
	weapon_type = "paint"
	max_ammo = 100
	current_ammo = 100
	reload_time = 1.0
	weapon_range = 300.0
	damage = 0
	fire_rate = 0.21
	ads_fov = 35.0
	hole_size = 1.5  
	
	# Override mesh and collision if needed
	mesh_instance = %Mesh
	collision_shape = %CollisionShape3D
	shoot_anim = %Paint_shoot
