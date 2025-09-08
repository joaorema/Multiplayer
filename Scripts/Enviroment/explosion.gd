extends Node3D
@onready var debris: GPUParticles3D = $Debris
@onready var fire: GPUParticles3D = $Fire
@onready var smoke: GPUParticles3D = $Smoke

func explode():
	# Change the actual particle scale in the process material
	if debris.process_material:
		debris.process_material.scale_min = 0.01
		debris.process_material.scale_max = 0.03
	
	if fire.process_material:
		fire.process_material.scale_min = 0.01
		fire.process_material.scale_max = 0.03
	
	if smoke.process_material:
		smoke.process_material.scale_min = 0.02
		smoke.process_material.scale_max = 0.05
	
	debris.emitting = true
	smoke.emitting = false
	fire.emitting = true
	await get_tree().create_timer(2.0).timeout
	print("boom")
