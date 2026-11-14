extends Node3D

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	# The camera is oriented once during loading and has no runtime controls in P1.
	camera.look_at(Vector3(32.0, 0.0, 32.0), Vector3.UP)
	print("P1_DIAGNOSTIC: WorldRoot ready; X/Z horizontal, Y vertical; Camera3D is static.")
