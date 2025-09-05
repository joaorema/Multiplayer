extends Node3D

#awp
@export var damage: int = 115
@export var max_ammo: int = 12      # reserve ammo
@export var clip_size: int = 1      # magazine capacity
@export var fire_rate: float = 1.5
var recoil_offset: Vector2 = Vector2.ZERO   # x = vertical, y = horizontal
@export var weapon_name = "awp"
@export var hole_size: float = 1.5   # <-- NEW (affects voxel terrain)
@export var recoil_strength: Vector2 = Vector2(1.0, 0.5) # up 1, right 0.5
@export var recoil_recovery: float = 10.0   # speed it goes back
@onready var animation_player: AnimationPlayer = %rotateawp

var current_ammo: int
var reserve_ammo: int
var last_shot_time: float = 0.0


func _ready() -> void:
	current_ammo = clip_size
	reserve_ammo = max_ammo
	animation_player.play("rotate")
	
func start_rotation() -> void:
	animation_player.play()

func stop_rotation() -> void:
	
	animation_player.stop()	

func fire() -> bool:
	
	if current_ammo <= 0:
		print("Click! (empty)")
		return false

	var now = Time.get_ticks_msec() / 1000.0
	if now - last_shot_time < fire_rate:
		return false # too soon, respect fire_rate

	current_ammo -= 1
	last_shot_time = now
	print("Bang! Ammo left:", current_ammo)
	# You can play muzzle flash, sound, animation here
	return true

func reload():
	
	var needed = clip_size - current_ammo
	var taken = min(needed, reserve_ammo)
	current_ammo += taken
	reserve_ammo -= taken
	print("Reloaded. Ammo:", current_ammo, "/", reserve_ammo)
