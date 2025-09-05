extends Area3D
class_name Weapon

@export var weapon_name: String = "AK47"
@export var weapon_type: String = "assault_rifle"


@onready var mesh_instance: MeshInstance3D = $ak47  # Fixed to match your scene structure
@onready var collision_shape: CollisionShape3D = %CollisionShape3D
@onready var pickup_label: Label3D = $PickupLabel

var is_picked_up: bool = false
var current_player_near: CharacterBody3D = null

func _ready():
	# Add to weapons group for easy finding
	add_to_group("weapons")
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Setup pickup label
	
	pickup_label.visible = false
	
	# Make sure only the server handles pickups initially
	set_multiplayer_authority(1)
	
	print("Weapon ready: ", weapon_name, " at position: ", global_position)

func _on_body_entered(body):
	print("Body entered weapon area: ", body.name)
	if body.is_in_group("PlayerCharacter") and not is_picked_up:
		current_player_near = body
		

func _on_body_exited(body):
	print("Body exited weapon area: ", body.name)
	if body == current_player_near:
		current_player_near = null
		
			



@rpc("any_peer", "call_local", "reliable")
func pickup_weapon(player_id: int):
	print("pickup_weapon called by player: ", player_id)
	if is_picked_up:
		print("Weapon already picked up!")
		return
	
	is_picked_up = true
	print("Weapon picked up: ", weapon_name)
	
	# Hide the weapon visually
	mesh_instance.visible = false
	collision_shape.disabled = true
	pickup_label.visible = false
	
	# Find the player and give them the weapon
	var players = get_tree().get_nodes_in_group("PlayerCharacter")
	for player in players:
		if player.get_multiplayer_authority() == player_id:
			player.pickup_weapon_rpc.rpc(weapon_type)
			print("Called pickup_weapon_rpc on player")
			break

@rpc("any_peer", "call_local", "reliable")
func drop_weapon(drop_position: Vector3):
	is_picked_up = false
	global_position = drop_position
	
	# Show the weapon again
	mesh_instance.visible = true
	collision_shape.disabled = false
