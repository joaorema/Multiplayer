extends CharacterBody3D

# Shooting variables
@export var max_ammo: int = 30
@export var current_ammo: int = 30
@export var reload_time: float = 2.0
@export var weapon_range: float = 100.0
@export var damage: int = 25
var is_reloading: bool = false
var can_shoot: bool = true
var last_shot_time: float = 0.0
var coin_count: int = 0

@onready var coin_label: Label = %CoinLabel
@onready var hp_label: Label = %Health
@onready var weapon_label: Label = %Weapon
@onready var hit_label: Label = %Shoot_Print
@onready var dot: Label = %Dot

@export var ads_fov: float = 40.0         # zoomed in field of view
@export var smg_fov: float = 60.0         # zoomed in field of view
@export var awp_fov: float = 10.0  
@export var ak_fov: float = 35.0 
@export var shotgun_fov: float = 60.0 
@export var normal_fov: float = 70.0      # default FOV
@export var ads_speed: float = 8.0        # how fast to interpolate
var is_ads: bool = false                  # are we aiming down sights?
@onready var hand_node: Node3D = %hand     



#weapon
@export var current_weapon: String = ""
var equipped_weapon_node: Node3D = null
@onready var weapon_holder: Node3D = %WeaponHolder

# Player.gd (your CharacterBody3D)

var controlled_rigid: RigidBody3D = null


#Player variables
@export var health: int
@export var is_dead: bool = false
@export var spawn_position: Vector3
@export var max_health: int = 100  # Enemy max health

#Player Label





#Loading
@onready var anim_player: AnimationPlayer = %AnimationPlayer	#Used to use animations
@onready var head: Node3D = %Head								#used for camera
@onready var collider: CollisionShape3D = %Collider				#player collison
@export var look_rotation: Vector2

@onready var camera: Camera3D = %playercamera




#Bools
@export var can_move: bool = true
@export var has_gravity: bool = true
@export var can_jump: bool = true
@export var can_double_jump: bool = true
@export var can_sprint: bool = true
@export var mouse_captured: bool = false
@export var has_weapon: bool = false
@export var is_in_car: bool = false
@export var is_in_rigid: bool = false
@export var can_fire: bool = true
var is_cheering: bool = false

#Movement variables
@export_group("Speeds")
@export var fire_rate: float = 0.2
@export var look_speed: float = 0.002
@export var base_speed: float = 4.5
@export var jump_velocity: float = 3
@export var sprint_speed: float = 15.0
@export var move_speed: float = 0.0
@export var move_distance: float = 2.0

#Input variables
@export_group("Input Actions")
@export var input_left: String = "move_left"
@export var input_right: String = "move_right"
@export var input_forward: String = "move_up"
@export var input_back: String = "move_down"
@export var input_jump: String = "ui_accept"
@export var input_sprint: String = "sprint"


func _enter_tree():
	set_multiplayer_authority(name.to_int())

#On start
func _ready() -> void:
	if get_multiplayer_authority():
		add_to_group("PlayerCharacter")
		health = max_health
		camera.current = is_multiplayer_authority()
		look_rotation.y = rotation.y
		look_rotation.x = head.rotation.x
		
#Unhandle_input
func _unhandled_input(event: InputEvent) -> void:
	if is_multiplayer_authority():
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			capture_mouse()
		if Input.is_key_pressed(KEY_ESCAPE):
			release_mouse()
	
		if event.is_action_pressed("cheer"):
			cheer()
		if event.is_action_pressed("interact"):  # Make sure to define "interact" in input map (E key)
			try_pickup_weapon()
			
		if event.is_action_pressed("drop_weapon") and has_weapon:  # Define "drop_weapon" in input map (G key)
			drop_current_weapon()
		
		if event.is_action_pressed("shoot") and has_weapon and can_shoot and not is_reloading:
			shoot()
		if event.is_action_pressed("aim"):
			is_ads = true
		if event.is_action_released("aim"):
			is_ads = false	
		if event.is_action_pressed("reload") and has_weapon and current_ammo < max_ammo and not is_reloading:
			reload_weapon()
		
		if mouse_captured and event is InputEventMouseMotion:
			rotate_look(event.relative)

func try_pickup_weapon():
	
	var overlapping_areas = []
	var all_areas = get_tree().get_nodes_in_group("weapons")  # We'll add weapons to this group
	for area in all_areas:
		if area is Weapon:
			# Check if player is close enough to the weapon
			var distance = global_position.distance_to(area.global_position)
			if distance <= 3.0 and not area.is_picked_up :  # 3 meter pickup range
				area.pickup_weapon.rpc(get_multiplayer_authority())
				return
	
@rpc("any_peer", "call_local", "reliable")
func pickup_weapon_rpc(weapon_type: String):
	if not has_weapon:
		current_weapon = weapon_type
		has_weapon = true
		create_weapon_visual(weapon_type)
		print("Player picked up: ", weapon_type)

func create_weapon_visual(weapon_type: String):
	# Remove existing weapon if any
	if equipped_weapon_node:
		equipped_weapon_node.queue_free()
	
	# Load weapon model based on type
	var weapon_scene_path = ""
	match weapon_type:
		"assault_rifle":
			weapon_scene_path = "C:/Multiplayer/Scenes/Weapons/Ak_47_Multiplayer.tscn"
		"sniper":
			weapon_scene_path = "res://weapons/awp_equipped.tscn"
		# Add more weapon types as needed
	
	if weapon_scene_path != "" and ResourceLoader.exists(weapon_scene_path):
		var weapon_scene = load(weapon_scene_path)
		equipped_weapon_node = weapon_scene.instantiate()
		weapon_holder.add_child(equipped_weapon_node)

func add_coin(amount: int = 1) -> void:
	coin_count += amount
	update_coin_display()

func update_coin_display() -> void:
	if coin_label:
		coin_label.text = "COINS: %d " % coin_count 

func drop_current_weapon():
	if not has_weapon:
		return
		
	drop_weapon_rpc.rpc(global_position + Vector3(0, 0, 1))

@rpc("any_peer", "call_local", "reliable")
func drop_weapon_rpc(drop_position: Vector3):
	if not has_weapon:
		return
		
	# Create dropped weapon in world
	var weapon_scene = load("C:/Multiplayer/Scenes/Weapons/Ak_47_Multiplayer.tscn")  # Your weapon pickup scene
	var dropped_weapon = weapon_scene.instantiate()
	dropped_weapon.weapon_type = current_weapon
	get_tree().current_scene.add_child(dropped_weapon)
	dropped_weapon.global_position = drop_position
	
	# Remove from player
	current_weapon = ""
	has_weapon = false
	
	if equipped_weapon_node:
		equipped_weapon_node.queue_free()
		equipped_weapon_node = null
	
	print("Player dropped weapon at: ", drop_position)

func cheer():
	is_cheering = true
	anim_player.play("Cheer")
	await anim_player.animation_finished
	is_cheering = false

func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		# Apply replicated look_rotation for other clients
		rotation.y = look_rotation.y
		head.rotation.x = look_rotation.x
		
#movement
func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false

func rotate_look(rot_input: Vector2):
	# Scale look speed based on camera FOV
	var fov_scale = camera.fov / normal_fov   # smaller FOV -> smaller sensitivity
	var adjusted_look_speed = look_speed * fov_scale

	look_rotation.x += rot_input.y * adjusted_look_speed
	look_rotation.y -= rot_input.x * adjusted_look_speed

	var min_angle = deg_to_rad(-80) # look almost straight down
	var max_angle = deg_to_rad(55)  # look almost straight up
	look_rotation.x = clamp(look_rotation.x, min_angle, max_angle)

	# Apply rotations
	rotation.y = look_rotation.y
	head.rotation.x = look_rotation.x

# Shooting function
# --- Shooting function (client/local) ---
func shoot():
	if current_ammo <= 0:
		print("Out of ammo!")
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_shot_time < fire_rate:
		return
	last_shot_time = now
	current_ammo -= 1
	can_fire = false
	var space_state := get_world_3d().direct_space_state
	var screen_center := get_viewport().get_visible_rect().size / 2
	var from := camera.project_ray_origin(screen_center)
	var to := from + camera.project_ray_normal(screen_center) * 1000.0
	var ray := PhysicsRayQueryParameters3D.new()
	ray.from = from
	ray.to = to
	ray.exclude = [self]
	var result := space_state.intersect_ray(ray)
	var hit_pos := Vector3.ZERO
	var collider_id := 0
	if result:
		hit_pos = result.position
		# IMPORTANT: don't send the collider object itself
		collider_id = result.collider.get_instance_id()
	# Only send primitives
	shoot_rpc.rpc(from, to, hit_pos, collider_id)
	if result:
		emit_signal("shot_hit", result.position, result.collider)
		print("Hit:", result.collider.name, "at", result.position)
		hit_label.set_text(result.collider.name)
	can_fire = true
	print("Ammo remaining: ", current_ammo)



@rpc("any_peer", "call_local", "reliable")
func shoot_rpc(from: Vector3, to: Vector3, hit_pos: Vector3, collider_id: int):

	# resolve collider locally from the ID
	if collider_id != 0:
		var hit_body := instance_from_id(collider_id)
		if is_instance_valid(hit_body) and hit_body is Node:
			if hit_body.is_in_group("PlayerCharacter"):
				hit_body.take_damage.rpc(damage, get_multiplayer_authority())
			if hit_body.has_method("take_damage"):
				hit_body.take_damage.rpc(damage, get_multiplayer_authority())

# Reload function
func reload_weapon():
	if is_reloading or current_ammo >= max_ammo:
		return
	is_reloading = true
	print("Reloading...")
	await get_tree().create_timer(reload_time).timeout
	current_ammo = max_ammo
	is_reloading = false
	print("Reload complete!")

# Damage system
@rpc("any_peer", "call_local", "reliable")
func take_damage(damage_amount: int, attacker_id: int):
	if is_dead:
		return
	health -= damage_amount
	print("Took ", damage_amount, " damage. Health: ", health)
	update_hp()
	if health <= 0:
		die()

func die():
	is_dead = true
	print("Player died!")
	# Optional: play a death animation first
	if anim_player.has_animation("Death"):
		anim_player.play("Death")
		await anim_player.animation_finished
	# Reset health
	health = max_health
	# Move back to spawn
	global_position = spawn_position
	velocity = Vector3.ZERO  # stop any movement
	# Reset state
	is_dead = false

func display_hp() -> void:
	hp_label.text = "HP: %d" % health

func update_hp() -> void:
	if not is_multiplayer_authority():
		return  # Only update your own HUD
	if hp_label:
		hp_label.text = "HP: %d" % health

func update_crosshair_position():
	if not dot:
		return
	
	# You might need to adjust the crosshair position based on FOV
	# This is more complex and depends on your UI setup
	var fov_ratio = camera.fov / normal_fov
	# Adjust dot position based on this ratio if needed

# --- Physics/movement ---
func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		if has_gravity:
			if not is_on_floor():
				velocity += get_gravity() * delta
		
		if can_jump:
			if Input.is_action_just_pressed(input_jump) and is_on_floor():
				velocity.y = jump_velocity

		if can_double_jump:
			if !is_on_floor() and Input.is_action_just_pressed(input_jump):
				velocity.y = jump_velocity
			
		move_speed = base_speed
		if can_sprint and Input.is_action_pressed(input_sprint):
			move_speed = sprint_speed

		var target_fov = normal_fov
		if is_ads:
			target_fov = ads_fov
		camera.fov = lerp(camera.fov, target_fov, ads_speed * delta)
		update_crosshair_position()
		
		if can_move:
			var input_dir := Input.get_vector(input_right, input_left, input_back, input_forward)
			var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		# Move the player
			velocity.x = move_dir.x * move_speed
			velocity.z = move_dir.z * move_speed
			if not is_cheering:
			# --- Animation ---
				if input_dir.y > 0:
					if anim_player.current_animation != "Walking_A":
						anim_player.play("Walking_A")
				elif input_dir.y < 0:
					if anim_player.current_animation != "Walking_Backwards":
						anim_player.play("Walking_Backwards")
				else:
					if anim_player.current_animation != "Idle":
						anim_player.play("Idle")
				if velocity.y > 0:
					if anim_player.current_animation != "Jump_Full_Short":
						anim_player.play("Jump_Full_Short")
			else:
				velocity.x = 0
				velocity.z = 0
				if anim_player.current_animation != "Idle" and not is_cheering:
					anim_player.play("Idle")
		move_and_slide()
