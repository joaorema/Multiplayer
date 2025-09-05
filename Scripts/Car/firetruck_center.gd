extends "res://scripts/guns_script/weaponcenter.gd"

@export var vehicle_body_path: NodePath
@export var vehicle_name: String = "firetruck"

func interact(player: Node) -> void:
	if player and player.is_in_group("PlayerCharacter"):
		var car = get_node(vehicle_body_path)
		if car:
			player.enter_rigid(car)  # ✅ call Player.gd's enter_car function
			print("Player entered: ", vehicle_name)
		else:
			print("ERROR: vehicle_body_path not found!")
