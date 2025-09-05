extends CharacterBody3D

@export var CoinScene: PackedScene
@onready var anim_enemy: AnimationPlayer = %enenyanimation

@export var attack_range: float = 10.0
@export var move_speed: float = 3.0
@export var rotation_speed: float = 5.0
@export var max_health: int = 100
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.5
@export var detection_range: float = 10.0

# Synchronized variables
var health: int
var is_dead: bool = false
var can_attack: bool = true

# Local variables
var nearest_player: Node3D = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var players_in_range: Array[Node3D] = []

func _ready():
	# Only the server controls enemies
	set_multiplayer_authority(1)  # Server has authority
	health = max_health
	
	# Set up a timer to periodically find players
	var timer = Timer.new()
	timer.wait_time = 0.5  # Check every 0.5 seconds
	timer.timeout.connect(_find_nearest_player)
	add_child(timer)
	timer.start()

func _find_nearest_player():
	"""Find the nearest player to this enemy"""
	var players = get_tree().get_nodes_in_group("PlayerCharacter")
	if players.is_empty():
		nearest_player = null
		return
	
	var closest_distance = INF
	var closest_player = null
	
	for player in players:
		if player.is_dead:  # Skip dead players
			continue
			
		var distance = global_position.distance_to(player.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_player = player
	
	# Only target player if within detection range
	if closest_distance <= detection_range:
		nearest_player = closest_player
	else:
		nearest_player = null

func _physics_process(delta: float) -> void:
	# Only server processes enemy AI
	if not is_multiplayer_authority():
		return
		
	if is_dead:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	if not nearest_player or not is_instance_valid(nearest_player):
		# No valid target - idle
		velocity = Vector3.ZERO
		if anim_enemy.current_animation != "Idle":
			play_animation_rpc.rpc("Idle")
		move_and_slide()
		return
	
	var direction = nearest_player.global_position - global_position
	direction.y = 0
	var distance = direction.length()
	direction = direction.normalized() if distance > 0 else Vector3.ZERO
	
	if distance > attack_range:
		# Move toward player
		var target_rotation_y = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation_y, rotation_speed * delta)
		
		var forward = transform.basis.z  # Forward direction
		velocity.x = forward.x * move_speed
		velocity.z = forward.z * move_speed
		
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = 0
		
		if anim_enemy.current_animation != "Running_A":
			play_animation_rpc.rpc("Running_A")
	else:
		# Within attack range - stop and attack
		velocity.x = 0
		velocity.z = 0
		
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = 0
		
		if can_attack:
			attack()
		elif anim_enemy.current_animation != "Idle":
			play_animation_rpc.rpc("Idle")
	
	move_and_slide()

@rpc("authority", "call_local", "reliable")
func play_animation_rpc(animation_name: String):
	"""Sync animations across all clients"""
	if anim_enemy.has_animation(animation_name):
		anim_enemy.play(animation_name)

func attack():
	"""Attack the nearest player"""
	if not nearest_player or not is_instance_valid(nearest_player):
		return
		
	can_attack = false
	play_animation_rpc.rpc("1H_Melee_Attack_Stab")
	
	# Wait a bit for the animation to reach the hit frame
	await get_tree().create_timer(0.5).timeout
	
	# Check if player is still in range and valid
	if nearest_player and is_instance_valid(nearest_player):
		var distance = global_position.distance_to(nearest_player.global_position)
		if distance <= attack_range:
			# Deal damage to the player
			if nearest_player.has_method("take_damage"):
				nearest_player.take_damage.rpc(attack_damage, 0)  # 0 = enemy attacker ID
	
	# Cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: int, attacker_id: int):
	"""Take damage from any player"""
	if is_dead:
		return
	
	# Only server processes damage
	if not is_multiplayer_authority():
		return
		
	health -= amount
	print("Enemy took ", amount, " damage. Health: ", health)
	
	if health <= 0:
		die()

@rpc("authority", "call_local", "reliable")
func die():
	"""Enemy death - only called by server"""
	if is_dead:
		return
		
	is_dead = true
	play_animation_rpc.rpc("Death_A")
	
	# Wait for death animation
	if anim_enemy.has_animation("Death_A"):
		await anim_enemy.animation_finished
	
	# Spawn coin (only on server)
	if is_multiplayer_authority() and CoinScene:
		var coin_instance = CoinScene.instantiate()
		get_parent().add_child(coin_instance)
		coin_instance.global_position = global_position
	
	# Remove enemy from scene
	queue_free()
