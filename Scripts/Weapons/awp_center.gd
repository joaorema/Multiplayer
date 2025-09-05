extends "C:/Multiplayer/Scripts/Enviroment/Interactable.gd"

@export var weapon_name: String = "awp"

func interact(player: Node) -> void:
	if player.is_in_group("PlayerCharacter"):
		# If player is not authority, ask the host to do the pickup
		if not player.is_multiplayer_authority():
			player.rpc_id(1, "rpc_request_pickup_weapon", get_path())
		else:
			player.pickup_weapon(self)
