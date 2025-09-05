extends CanvasLayer

@onready var dot = %Dot  # TextureRect at center


func _ready():
	# shift dot slightly up by 5 pixels
	dot.position.y -= 40
	dot.position.x -= 20
#
