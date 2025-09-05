extends "C:/Multiplayer/Scripts/Enviroment/Interactable.gd"

@export var weapon_name: String = "ak_47"

func interact(player: Node) -> void:
	if player.is_in_group("PlayerCharacter"):
		player.pickup_weapon(self)  # delegate pickup to playe
