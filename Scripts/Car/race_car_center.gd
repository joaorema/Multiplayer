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
	print("Controlled Rigid: ", controlled_rigid)

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody3D:
		body.set_meta("near_car", self)

func _on_body_exited(body: Node) -> void:
	if body is CharacterBody3D and body.get_meta("near_car") == self:
		body.set_meta("near_car", null)

func enter(driver_player: CharacterBody3D) -> void:
	driver = driver_player
	driver.visible = false
	driver.can_move = false
	driver.is_in_car = true
	driver.controlled_rigid = controlled_rigid  # now this points to the actual RigidBody3D
	driver.camera.current = false
	
	car_camera.current = true
	print("Player entered car:", controlled_rigid.name)


func exit() -> void:
	if driver:
		driver.visible = true
		driver.can_move = true
		driver.is_in_car = false
		var car_transform = controlled_rigid.global_transform
		global_transform.origin = car_transform.origin + -car_transform.basis.x * -2.0
		driver.controlled_rigid = null  # 👈 stop controlling
		driver.camera.current = true
		car_camera.current = false
		car.set_multiplayer_authority(1)
		driver = null
