extends CharacterBody3D
# Change this line at the top of your player script:
signal shot_hit(position: Vector3, collider: Node, hole_size: float, weapon_type: String)
signal punch_hit(position: Vector3, collider: Node)
# Current weapon stats (will be set by picked up weapon)
var weapon_stats: Dictionary = {}
var is_reloading: bool = false
var can_shoot: bool = true
var last_shot_time: float = 0.0
var coin_count: int = 0
var is_punching : bool = false

var last_viewer_update_pos: Vector3
@onready var coin_label: Label = %CoinLabel
@onready var hp_label: Label = %Health
@onready var weapon_label: Label = %Weapon
@onready var hit_label: Label = %Shoot_Print
@onready var dot: Label = %Dot
@onready var bullet_image : Sprite2D = %NormalBullet
@onready var equiped_weapon : Area3D
@export var ak_scene: PackedScene 
@export var awp_scene: PackedScene
@export var smg_scene: PackedScene
@export var paint_scene: PackedScene   
@export var shotgun_scene: PackedScene  
@export var bullet_shotgun: PackedScene  
@export var explosion_scene: PackedScene  
@onready var no_ammo_sound: AudioStreamPlayer2D = %no_ammo
@onready var reload_sound: AudioStreamPlayer2D = %reload
@onready var awp_sound: AudioStreamPlayer2D = %awp_sound
@onready var ak_sound: AudioStreamPlayer2D = %ak_sound
@onready var smg_sound: AudioStreamPlayer2D = %Smg_sound
@onready var paint_sound: AudioStreamPlayer2D = %paint_sound
@onready var shotgun_sound: AudioStreamPlayer2D = %shotgun_sound
@onready var punch_sound: AudioStreamPlayer2D = %punch_sound

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


var can_enter_car: bool = false
var nearby_car: RigidBody3D = null

#Movement variables
@export_group("Speeds")
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
		bullet_image.hide()
		
		

#Unhandle_input
func _unhandled_input(event: InputEvent) -> void:
	if is_multiplayer_authority():
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			capture_mouse()
		if Input.is_key_pressed(KEY_ESCAPE):
			release_mouse()
	
		if event.is_action_pressed("cheer"):
			cheer()
		if event.is_action_pressed("interact") and !has_weapon and !is_in_car:  # Make sure to define "interact" in input map (E key)
			try_pickup_weapon()
			
		if event.is_action_pressed("drop_weapon") and has_weapon:  # Define "drop_weapon" in input map (G key)
			drop_current_weapon()
		if event.is_action_pressed("interact"):
			if not is_in_car and get_meta("can_enter_car", false):
				# Entering car
				var car_center = get_meta("near_car", null)
				if car_center:
					car_center.enter(self)
			elif is_in_car:
				# Exiting car - call the car's exit function
				var car_center = get_meta("near_car", null)
				if car_center:
					car_center.exit()
				else:
					# Fallback - force exit if no car_center found
					force_exit_car()
		
		if event.is_action_pressed("shoot") and !has_weapon:  # Define "punch" in input map (like F key)
			punch()
			punch_sound.play()
			
			
		if event.is_action_pressed("shoot") and has_weapon and can_shoot and not is_reloading:
			shoot()
		if event.is_action_pressed("aim"):
			is_ads = true
		if event.is_action_released("aim"):
			is_ads = false	
		if event.is_action_pressed("reload") and has_weapon and get_current_ammo() < get_max_ammo() and not is_reloading:
			reload_weapon()
		
		if event.is_action_pressed("destroy"):  # or any other key
			test_terrain_destruction()
		
		if mouse_captured and event is InputEventMouseMotion:
			rotate_look(event.relative)

func force_exit_car():
	if controlled_rigid:
		controlled_rigid.set_multiplayer_authority(1)
		controlled_rigid = null
	
	is_in_rigid = false
	is_in_car = false
	can_move = true
	visible = true
	
	# Restore camera
	camera.current = true
	
	# Optionally, disable car camera
	var car_camera_target = get_tree().current_scene.get_node_or_null("Path/To/Car/carcamera")
	if car_camera_target:
		car_camera_target.current = false

func punch():
	print("Player punching!")
	
	var space_state := get_world_3d().direct_space_state
	var screen_center := get_viewport().get_visible_rect().size / 2
	var from := camera.project_ray_origin(screen_center)
	var to := from + camera.project_ray_normal(screen_center) * 0.3  # Short punch range
	
	var ray := PhysicsRayQueryParameters3D.new()
	ray.from = from
	ray.to = to
	ray.exclude = [self]
	
	var result := space_state.intersect_ray(ray)
	
	if result:
		var hit_pos: Vector3 = result["position"]
		var collider: Node = result["collider"]
		var punch_direction = (to - from).normalized()
		
		emit_signal("punch_hit", hit_pos, collider)
		hit_label.text = "Punched: %s" % [collider.name]
		
		# Apply knockback to enemies
		if collider.has_method("take_damage"):
			collider.take_damage.rpc(15, get_multiplayer_authority(), punch_direction)  # 25 punch damage
		
		# --- PUSH RIGIDBODY ---
		var rb := get_rigidbody_from_collider(collider)
		if rb:
			var push_dir = (hit_pos - global_transform.origin).normalized()
			var push_strength = 3.0  # tweak this
			rb.apply_central_impulse(push_dir * push_strength)
	else:
		# Still emit signal for terrain interaction
		emit_signal("punch_hit", to, null)
		hit_label.text = "Punched air"
	
	is_punching = true
	anim_player.play("1H_Melee_Attack_Stab")
	await anim_player.animation_finished

	
func get_rigidbody_from_collider(node: Node) -> RigidBody3D:
	var body: Node = node
	while body and not (body is RigidBody3D):
		body = body.get_parent()
	return body if body is RigidBody3D else null

func test_terrain_destruction():
	var test_pos = global_position + Vector3(0, -1, 0)  # Below player
	var terrain = get_tree().get_first_node_in_group("terrain")
	if terrain:
		terrain._on_player_shot_hit(test_pos, terrain, 3.0, current_weapon)

func try_pickup_weapon():
	var areas = get_tree().get_nodes_in_group("weapons")
	for area in areas:
		if area is Weapon and not area.is_picked_up:
			if global_position.distance_to(area.global_position) <= 1.0:
				area.pickup_weapon.rpc(get_multiplayer_authority())
				return
				

@rpc("any_peer", "call_local", "reliable")
func pickup_weapon_rpc(weapon_type: String, stats: Dictionary):
	if not has_weapon:
		current_weapon = weapon_type
		has_weapon = true
		weapon_stats = stats.duplicate()  # Store weapon stats
		create_weapon_visual(weapon_type)
		update_weapon_display()
		print("weapon:", current_weapon)
		bullet_image.show()
		weapon_label.show()

func create_weapon_visual(weapon_type: String):
	# Remove existing weapon if any
	if equipped_weapon_node:
		equipped_weapon_node.queue_free()
	
	# Get weapon scene path
	var weapon_scene_path = get_weapon_scene_path(weapon_type)
	var weapon_scene = weapon_scene_path
	equipped_weapon_node = weapon_scene.instantiate()
	equiped_weapon = equipped_weapon_node
	weapon_holder.add_child(equipped_weapon_node)
	print("Successfully loaded weapon visual")
	
		

func add_coin(amount: int = 1) -> void:
	coin_count += amount
	update_coin_display()

func update_coin_display() -> void:
	if coin_label:
		coin_label.text = "COINS: %d " % coin_count 

func update_weapon_display() -> void:
	if weapon_label and has_weapon:
		weapon_label.text = "%d/%d" % [get_current_ammo(), get_max_ammo()]

func get_weapon_scene_path(weapon_type: String) -> PackedScene:
	# Return the correct scene path based on weapon type
	match weapon_type.to_lower():
		"assault_rifle":
			return ak_scene
		"sniper":
			return awp_scene
		"semi_automatic":
			return smg_scene
		"paint":
			return paint_scene
		"shotgun":
			return shotgun_scene
		_:
			return null

func drop_current_weapon():
	if not has_weapon:
		return
		
	drop_weapon_rpc.rpc(global_position + Vector3(0, 0.4, 0))
	

@rpc("any_peer", "call_local", "reliable")
func drop_weapon_rpc(drop_position: Vector3):
	if not has_weapon:
		return
		
	# Create dropped weapon in world
	var weapon_scene_path = get_weapon_scene_path(current_weapon)
	var weapon_scene = weapon_scene_path  # Your weapon pickup scene
	var dropped_weapon = weapon_scene.instantiate()
	dropped_weapon.weapon_type = current_weapon
	get_tree().current_scene.add_child(dropped_weapon)
	dropped_weapon.global_position = drop_position
	
	# Clear weapon from player
	current_weapon = ""
	has_weapon = false
	weapon_stats.clear()
	
	if equipped_weapon_node:
		equipped_weapon_node.queue_free()
		equipped_weapon_node = null
	
	
	weapon_label.hide()
	bullet_image.hide()

func cheer():
	is_cheering = true
	anim_player.play("Cheer")
	await anim_player.animation_finished
	is_cheering = false

# Weapon stat getters
func get_damage() -> int:
	return weapon_stats.get("damage", 0)

func get_max_ammo() -> int:
	return weapon_stats.get("max_ammo", 0)

func get_current_ammo() -> int:
	return weapon_stats.get("current_ammo", 0)

func set_current_ammo(ammo: int):
	weapon_stats["current_ammo"] = ammo

func get_reload_time() -> float:
	return weapon_stats.get("reload_time", 2.0)

func get_fire_rate() -> float:
	return weapon_stats.get("fire_rate", 0.2)

func get_weapon_range() -> float:
	return weapon_stats.get("weapon_range", 100.0)

func get_hole_size() -> float:
	return weapon_stats.get("hole_size", 2.0)

func get_ads_fov() -> float:
	return weapon_stats.get("ads_fov", 40.0)

func _process(delta: float) -> void:
	if is_multiplayer_authority() and has_weapon and can_shoot and not is_reloading:
		if Input.is_action_pressed("shoot"):
			shoot()
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
	# Scale look speed automatically with FOV
	var fov_scale = camera.fov / normal_fov
	var adjusted_look_speed = look_speed * fov_scale

	look_rotation.x += rot_input.y * adjusted_look_speed
	look_rotation.y -= rot_input.x * adjusted_look_speed

	var min_angle = deg_to_rad(-80)
	var max_angle = deg_to_rad(55)
	look_rotation.x = clamp(look_rotation.x, min_angle, max_angle)

	rotation.y = look_rotation.y
	head.rotation.x = look_rotation.x


# Shooting function
func shoot():
	var current_ammo = get_current_ammo()
	if current_ammo <= 0:
		print("Out of ammo!")
		no_ammo_sound.play()
		return
	
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_shot_time < get_fire_rate():
		return
	last_shot_time = now
	
	set_current_ammo(current_ammo - 1)
	can_fire = false

	var space_state := get_world_3d().direct_space_state
	var screen_center := get_viewport().get_visible_rect().size / 2
	var from := camera.project_ray_origin(screen_center)

	if current_weapon == "shotgun":
		var pellets := 8
		var spread := 5.0 # degrees
		
		for i in range(pellets):
			var dir := camera.project_ray_normal(screen_center)

			var random_rot := Basis(
				Vector3.UP, deg_to_rad(randf_range(-spread, spread))
			) * Basis(
				Vector3.RIGHT, deg_to_rad(randf_range(-spread, spread))
			)
			dir = (random_rot * dir).normalized()

			var to := from + dir * get_weapon_range()
			var ray := PhysicsRayQueryParameters3D.new()
			ray.from = from
			ray.to = to
			ray.exclude = [self]

			var result := space_state.intersect_ray(ray)

			var hit_pos := Vector3.ZERO
			var collider_id := 0
			if result:
				hit_pos = result["position"]         # <<< dictionary access
				var collider = result["collider"]   # <<< dictionary access
				collider_id = collider.get_instance_id()

				emit_signal("shot_hit", hit_pos, collider, get_hole_size(), current_weapon)
				hit_label.text = "Hit: %s" % [collider.name]

				if i == 0:
					spawn_explosion_at_position(hit_pos)

				# --- PUSH RIGIDBODIES ---
				var rb := get_rigidbody_from_collider(collider)
				if rb:
					var impact_dir = (to - from).normalized()
					var bullet_push = 6.0   # tweak per-weapon
					rb.apply_central_impulse(impact_dir * bullet_push)

			else:
				hit_label.text = "Missed with one pellet"

			shoot_rpc.rpc(from, to, hit_pos, collider_id, get_damage())

	else:
		var to := from + camera.project_ray_normal(screen_center) * get_weapon_range()
		var ray := PhysicsRayQueryParameters3D.new()
		ray.from = from
		ray.to = to
		ray.exclude = [self]

		var result := space_state.intersect_ray(ray)

		var hit_pos := Vector3.ZERO
		var collider_id := 0
		if result:
			hit_pos = result["position"]
			var collider = result["collider"]
			collider_id = collider.get_instance_id()

			emit_signal("shot_hit", hit_pos, collider, get_hole_size(), current_weapon)
			hit_label.text = "Hit: %s" % [collider.name]
			spawn_explosion_at_position(hit_pos)

			# --- PUSH RIGIDBODIES ---
			var rb := get_rigidbody_from_collider(collider)
			if rb:
				var impact_dir = (to - from).normalized()
				var bullet_push = 10.0  # tweak strength for rifles/pistols
				rb.apply_central_impulse(impact_dir * bullet_push)

		else:
			hit_label.text = "Hit nothing"

		shoot_rpc.rpc(from, to, hit_pos, collider_id, get_damage())
	
	# --- Sounds & animations ---
	if current_weapon == "sniper":
		awp_sound.play()    
		equiped_weapon.shoot_anim.play("shoot")
	if current_weapon == "assault_rifle":
		ak_sound.play()
		equiped_weapon.shoot_anim.play("shoot")
	if current_weapon == "semi_automatic":
		smg_sound.play()
		equiped_weapon.shoot_anim.play("shoot")
	if current_weapon == "paint":
		paint_sound.play()
		equiped_weapon.shoot_anim.play("shoot")
	if current_weapon == "shotgun":
		shotgun_sound.play()
		equiped_weapon.shoot_anim.play("shoot")
		spawn_bullet()
		spawn_explosion()
	
	can_fire = true
	update_weapon_display()



func interact_with_terrain(position: Vector3, operation: String):
	if is_multiplayer_authority():
		var terrain = get_tree().get_first_node_in_group("terrain")
		if terrain:
			terrain.request_terrain_modification(position, 2.0, operation)


@rpc("any_peer", "call_local", "reliable")
func shoot_rpc(from: Vector3, to: Vector3, hit_pos: Vector3, collider_id: int, damage: int):
	if collider_id != 0:
		var hit_body := instance_from_id(collider_id)
		if is_instance_valid(hit_body) and hit_body is Node:
			var knockback_direction = (to - from).normalized()
			
			# Apply weapon-specific knockback multiplier
			var knockback_multiplier = 1.0
			match current_weapon:
				"shotgun":
					knockback_multiplier = 0.8  # Slightly less than default
				"sniper":
					knockback_multiplier = 1.2  # Bit more for sniper
				"assault_rifle":
					knockback_multiplier = 0.6  # Less for rapid fire
				"semi_automatic":
					knockback_multiplier = 0.5  # Least for SMG
				"paint":
					knockback_multiplier = 0.3  # Very little for paint
			
			# Scale the knockback direction
			knockback_direction *= knockback_multiplier
			
			if hit_body.is_in_group("PlayerCharacter"):
				hit_body.take_damage.rpc(damage, get_multiplayer_authority())
			elif hit_body.has_method("take_damage"):
				hit_body.take_damage.rpc(damage, get_multiplayer_authority(), knockback_direction)
			
			shot_hit.emit(hit_pos, hit_body, get_hole_size(), current_weapon)
	else:
		shot_hit.emit(hit_pos, null, get_hole_size(), current_weapon)

# Reload function
func reload_weapon():
	if is_reloading or get_current_ammo() >= get_max_ammo():
		return
	is_reloading = true
	reload_sound.play()
	await get_tree().create_timer(get_reload_time()).timeout
	set_current_ammo(get_max_ammo())
	is_reloading = false
	print("Reload complete!")
	update_weapon_display()

# Damage system
@rpc("any_peer", "call_local", "reliable")
func take_damage(damage_amount: int, attacker_id: int):
	if is_dead:
		return
	health -= damage_amount
	
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
	hp_label.text = ""
	if not is_multiplayer_authority():
		return  # Only update your own HUD
	if hp_label:
		hp_label.text = "HP: %d" % health

func update_crosshair_position():
	if not dot:
		return
	var fov_ratio = camera.fov / normal_fov
	

func update_voxel_viewers():
	var current_pos = global_position
	
	# If in car, use car position for voxel viewer
	if is_in_rigid and controlled_rigid:
		current_pos = controlled_rigid.global_position
	
	if current_pos.distance_to(last_viewer_update_pos) < 1.0:
		return
	# Only update if player has moved significantly (optimization)
	if global_position.distance_to(last_viewer_update_pos) < 1.0:
		return
	
	last_viewer_update_pos = global_position
	
	# Update local viewer (client side)
	var game_world = get_tree().current_scene
	if game_world and game_world.has_method("update_local_viewer_position"):
		game_world.update_local_viewer_position()
	
	# Update server viewer for this player
	if game_world and game_world.has_method("update_player_viewer_position"):
		game_world.update_player_viewer_position(get_multiplayer_authority(), global_position)

func handle_rigid_input():
	if not controlled_rigid:
		return
	
	if is_in_rigid:
		# Calculate inputs
		var steering = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
		var throttle = Input.get_action_strength("move_up")
		var brake = Input.get_action_strength("move_down")
		var handbrake = Input.get_action_strength("sprint")
		
		# Send inputs to car (this works for both local and networked cars)
		if controlled_rigid.has_method("update_inputs"):
			controlled_rigid.update_inputs(steering, throttle, brake, handbrake)
		else:
			# Fallback for old system
			controlled_rigid.steering_input = steering
			controlled_rigid.throttle_input = throttle
			controlled_rigid.brake_input = brake
			controlled_rigid.handbrake_input = handbrake

func enter_car(car: RigidBody3D):
	print("Entering car")
	controlled_rigid = car
	is_in_rigid = true
	can_move = false
	
	# Hide player
	visible = false
	
	# Give this player authority over the car
	car.set_multiplayer_authority(get_multiplayer_authority())
	
	# Switch cameras
	var car_camera_target: Camera3D = car.get_node_or_null("carcamera")
	if car_camera_target:
		
		camera.current = false                # disable player camera
		car_camera_target.current = true      # enable car camera
	else:
		push_warning("No CarCamera found on car: %s" % car.name)

func spawn_bullet():
	if not current_weapon: return
	
	var bullet_scene = bullet_shotgun
	var bullet_instance = bullet_scene.instantiate()
	
	# Position and rotation at muzzle
	var muzzle = equiped_weapon.get_node("Muzzle")
	bullet_instance.global_transform = muzzle.global_transform
	
	# Add to scene
	get_tree().current_scene.add_child(bullet_instance)
	var bullet_speed : float = 0.5
	# Give it velocity
	bullet_instance.linear_velocity = muzzle.global_transform.basis.z * -bullet_speed
	
func spawn_explosion_at_position(hit_position: Vector3):
	if not current_weapon: return
	
	var explosion_instance = explosion_scene.instantiate()
	
	# Position exactly at the hit point
	explosion_instance.global_transform.origin = hit_position
	
	# Add to the scene
	get_tree().current_scene.add_child(explosion_instance)
	
	# Trigger the explosion particles
	explosion_instance.explode()

func spawn_explosion():
	if not current_weapon: return
	
	var explosion_scene = explosion_scene
	var explosion_instance = explosion_scene.instantiate()
	
	# Position at the muzzle
	var muzzle = equiped_weapon.get_node("Muzzle")
	var forward_dir = muzzle.global_transform.basis.x.normalized()  # Try X axis
	var spawn_pos = muzzle.global_transform.origin + forward_dir * 10.0
	explosion_instance.global_transform.origin = spawn_pos
	
	# Add to the scene
	get_tree().current_scene.add_child(explosion_instance)
	
	# Trigger the explosion particles
	explosion_instance.explode()

func exit_car():
	print("Exiting car")
	if controlled_rigid:
		# Remove car authority
		controlled_rigid.set_multiplayer_authority(1)  # Give back to server
		controlled_rigid = null
	
	is_in_rigid = false
	can_move = true
	visible = true
	
	# Restore camera to player
	camera.current = true
	
	# Optionally, disable car camera
	var car_camera_target = get_tree().current_scene.get_node_or_null("Path/To/Car/carcamera")
	if car_camera_target:
		car_camera_target.current = false

# Detect nearby cars
func _on_car_detection_area_entered(area):
	if area.get_parent() is RigidBody3D:
		nearby_car = area.get_parent()
		can_enter_car = true
		

func _on_car_detection_area_exited(area):
	if area.get_parent() == nearby_car:
		nearby_car = null
		can_enter_car = false
		
var base_sensitivity := 0.5
var ads_sensitivity := 0.001  # how much slower mouse feels when ADS
var current_sensitivity := 1.0
var sensitivity_lerp_speed := 8.0  # how fast sensitivity adjusts

# --- Physics/movement ---
func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		if has_gravity:
			if not is_on_floor():
				velocity += get_gravity() * delta
				
		update_voxel_viewers()
		if is_in_rigid:
			handle_rigid_input()
			return
		if can_jump:
			if Input.is_action_just_pressed(input_jump) and is_on_floor():
				velocity.y = jump_velocity

		if can_double_jump:
			if !is_on_floor() and Input.is_action_just_pressed(input_jump):
				velocity.y = jump_velocity
			
		move_speed = base_speed
		if can_sprint and Input.is_action_pressed(input_sprint):
			move_speed = sprint_speed

		# --- FOV ADS transition ---
		var target_fov = normal_fov
		var target_sense = base_sensitivity
		if is_ads and has_weapon:
			target_fov = get_ads_fov()
			target_sense = ads_sensitivity
		
		camera.fov = lerp(camera.fov, target_fov, ads_speed * delta)
		current_sensitivity = lerp(current_sensitivity, target_sense, sensitivity_lerp_speed * delta)

		update_crosshair_position()
		
		if can_move:
			var input_dir := Input.get_vector(input_right, input_left, input_back, input_forward)
			var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		# Move the player
			velocity.x = move_dir.x * move_speed
			velocity.z = move_dir.z * move_speed
			if not is_cheering :
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
		# --- PUSH RIGIDBODIES YOU TOUCH ---
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsShapeQueryParameters3D.new()
		query.shape = %Collider.shape   # player’s own collider
		query.transform = global_transform
		query.exclude = [self]
		
#player force against rigid bodys
		var collisions = space_state.intersect_shape(query, 4)
		for result in collisions:
			var collider = result["collider"]
			var rb := get_rigidbody_from_collider(collider)
			if rb:
				var horizontal_vel = velocity
				horizontal_vel.y = 0.4
				if horizontal_vel.length() > 0.1:
					var push_dir = horizontal_vel.normalized()
					rb.apply_central_impulse(push_dir * 5.0)  # tweak strength
