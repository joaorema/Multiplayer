extends "C:/Multiplayer/Scripts/Enviroment/Interactable.gd"

@export var ammo_amount: int = 24   # how much ammo this box gives


func interact(player: Node) -> void:
	if not player.is_in_group("PlayerCharacter"):
		return

	# Make sure the player has a weapon
	if not player.has_weapon or player.current_weapon == null:
		print("No weapon to add ammo to!")
		return

	var weapon = player.current_weapon
	var amount = weapon.clip_size
	weapon.reserve_ammo += amount
	player.update_weapon_display()
	# Remove the ammo box from the world
	if get_parent() != null:
		get_parent().queue_free()
	else:
		queue_free()
