extends Area3D
class_name CarCenter

@onready var area: Area3D = %EnterArea
@onready var car: Node3D = get_parent() # assumes this is a child of the car root
@onready var car_camera: Camera3D = %carcamera
@onready var controlled_rigid: RigidBody3D = get_parent() as RigidBody3D
@export var is_in_rigid : bool = false
var driver: CharacterBody3D = null

func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody3D and body.is_in_group("PlayerCharacter"):
		print("Player ", body.name, " entered car area")
		body.set_meta("near_car", self)
		body.set_meta("can_enter_car", true)

func _on_body_exited(body: Node) -> void:
	if not (body is CharacterBody3D) or not body.is_in_group("PlayerCharacter"):
		return

	# If this body is currently driving the car, ignore the area exit.
	# This prevents the area leaving event (which can happen after teleport/hide)
	# from clearing the near_car metadata while the player is in the car.
	if driver and body == driver:
		print("Ignored area exit for driver:", body.name)
		return

	# Otherwise only clear meta if it actually belongs to this CarCenter
	if body.get_meta("near_car") == self:
		print("Player ", body.name, " left car area")
		body.set_meta("near_car", null)
		body.set_meta("can_enter_car", false)

func enter(driver_player: CharacterBody3D) -> void:
	if driver:  # Car already occupied
		print("Car already occupied!")
		return
		
	print("Player ", driver_player.name, " entering car")
	driver = driver_player
	driver.visible = false
	driver.can_move = false
	driver.is_in_car = true
	driver.is_in_rigid = true
	driver.controlled_rigid = controlled_rigid
	driver.camera.current = false
	
	car_camera.current = true
	is_in_rigid = true
	
	# IMPORTANT: Set car authority to the driver
	controlled_rigid.set_multiplayer_authority(driver.get_multiplayer_authority())
	
	# If the car has a MultiplayerSynchronizer, update its authority too
	var sync_node = controlled_rigid.get_node_or_null("MultiplayerSynchronizer")
	if sync_node:
		sync_node.set_multiplayer_authority(driver.get_multiplayer_authority())

func exit() -> void:
	if not driver:
		return
		
	print("Player ", driver.name, " exiting car")
	
	# Position player outside the car FIRST
	var car_transform = controlled_rigid.global_transform
	var exit_position = car_transform.origin + -car_transform.basis.x * -2.0
	
	driver.global_position = exit_position
	driver.visible = true
	driver.can_move = true
	driver.is_in_car = false
	driver.is_in_rigid = false
	
	driver.controlled_rigid = null
	driver.camera.current = true
	car_camera.current = false
	
	# Give car authority back to server (peer 1)
	controlled_rigid.set_multiplayer_authority(1)
	
	# If the car has a MultiplayerSynchronizer, update its authority too
	var sync_node = controlled_rigid.get_node_or_null("MultiplayerSynchronizer")
	if sync_node:
		sync_node.set_multiplayer_authority(1)
	
	driver = null
	is_in_rigid = false
