# Weapon.gd
extends "C:/Multiplayer/Scripts/Enviroment/Interactable.gd"
class_name Weapon


func interact(player: Node) -> void:
	if player.is_in_group("PlayerCharacter"):
		player.pickup_weapon(self)  # delegate pickup to player
