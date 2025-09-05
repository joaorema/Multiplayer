# weapon.gd
extends Area3D
class_name Weapon

@export var weapon_name: String = "Generic Weapon"
@export var weapon_type: String = "generic"
@export var max_ammo: int = 30
@export var current_ammo: int = 30
@export var reload_time: float = 2.0
@export var weapon_range: float = 100.0
@export var damage: int = 25
@export var fire_rate: float = 0.2
@export var ads_fov: float = 40.0
@export var hole_size: float = 1.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var is_picked_up: bool = false
var current_player_near: CharacterBody3D = null

func _ready():
	add_to_group("weapons")
	print("Weapon collision shape enabled? ", not collision_shape.disabled)
	print("Weapon collision layer: ", collision_layer, " mask: ", collision_mask)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_multiplayer_authority(1)

func _on_body_entered(body):
	if body.is_in_group("PlayerCharacter") and not is_picked_up:
		current_player_near = body

func _on_body_exited(body):
	if body == current_player_near:
		current_player_near = null

@rpc("any_peer", "call_local", "reliable")
func pickup_weapon(player_id: int):
	if is_picked_up: return
	is_picked_up = true
	mesh_instance.visible = false
	collision_shape.disabled = true
	
	var players = get_tree().get_nodes_in_group("PlayerCharacter")
	for player in players:
		if player.get_multiplayer_authority() == player_id:
			# Pass weapon stats to player
			player.pickup_weapon_rpc.rpc(weapon_type, get_weapon_stats())
			break

# Return weapon stats as a dictionary
func get_weapon_stats() -> Dictionary:
	return {
		"damage": damage,
		"max_ammo": max_ammo,
		"current_ammo": current_ammo,
		"reload_time": reload_time,
		"weapon_range": weapon_range,
		"fire_rate": fire_rate,
		"ads_fov": ads_fov,
		"hole_size": hole_size
	}

@rpc("any_peer", "call_local", "reliable")
func drop_weapon(drop_position: Vector3):
	is_picked_up = false
	global_position = drop_position
	mesh_instance.visible = true
	collision_shape.disabled = false
