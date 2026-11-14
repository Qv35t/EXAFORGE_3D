extends Node3D

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	# P4 starts from a deterministic initial view; CameraRig3D owns runtime controls.
	camera.look_at(Vector3(32.0, 0.0, 32.0), Vector3.UP)
	print("WORLD_DIAGNOSTIC: WorldRoot ready; X/Z horizontal, Y vertical; CameraRig3D owns controls.")
