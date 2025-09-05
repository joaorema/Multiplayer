extends Node3D

@onready var anim_enemy: AnimationPlayer = %AnimationPlayer
@onready var area: Area3D = %Area3D

@export var value: int = 1  # how much the coin is worth

func _ready() -> void:
	anim_enemy.play("Spin")
	area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("PlayerCharacter"):  # make sure Player is in the "Player" group
		print("Coin collected by:", body.name)
		body.add_coin(1) 
		await get_tree().create_timer(0.13).timeout
		# TODO: Add score/HP/etc here
		queue_free()  # remove coin after pickup# remove coin after pickup
