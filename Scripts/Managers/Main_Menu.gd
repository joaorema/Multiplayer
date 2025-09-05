extends Control

@onready var start_button: Button = %StartButton
@onready var quit_button: Button = %ExitButton
@onready var controll_button: Button = %Controls
@onready var info_popup: PopupPanel = %Controlls_Info

@export var game_scene: PackedScene = preload("res://Scenes/Game_Scene/World.tscn")
@export var popup_open: bool = false


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_packed(game_scene)

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_controls_pressed() -> void:
	if not popup_open:
		info_popup.popup()
		popup_open = true
	else:
		info_popup.hide()
		popup_open = false
