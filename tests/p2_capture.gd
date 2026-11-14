extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const OUTPUT_PATH := "res://artifacts/p2_terrain.png"

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.add_child(MAIN_SCENE.instantiate())
	await process_frame
	await process_frame
	var viewport_texture: ViewportTexture = root.get_texture()
	if viewport_texture == null:
		push_error("The active display driver did not create a framebuffer.")
		quit(1)
		return
	var image: Image = viewport_texture.get_image()
	var result: Error = image.save_png(OUTPUT_PATH)
	if result == OK:
		print("P2_SCREENSHOT: %s (%dx%d)" % [OUTPUT_PATH, image.get_width(), image.get_height()])
		quit(0)
	else:
		push_error("Unable to save screenshot: %s" % error_string(result))
		quit(1)
