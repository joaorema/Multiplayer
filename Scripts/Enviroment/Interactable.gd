# Interactable.gd
extends Area3D

@export var interact_text: String = "Press E to interact"

# Called when the player interacts with this object
func interact(player: Node) -> void:
	# To be overridden by child scripts
	pass
