extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const FOCUS := Vector3(32.0, 0.0, 32.0)
const BELT_TOP := Vector3(20.5, 1.0, 20.5)

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: Node3D = MAIN_SCENE.instantiate() as Node3D
	root.add_child(world)
	await physics_frame
	await physics_frame

	var camera: Camera3D = world.get_node_or_null("Camera3D") as Camera3D
	var rig: CameraRig3D = world.get_node_or_null("CameraRig3D") as CameraRig3D
	var router: InputRouter = world.get_node_or_null("InputRouter") as InputRouter
	if camera == null or rig == null or router == null:
		_expect(false, "P4 setup exposes Camera3D, CameraRig3D, and InputRouter")
		_finish()
		return

	_expect(_screen_directions_hold_at_four_azimuths(camera, rig), "T-04.1 WASD uses screen directions at four azimuths")
	_expect(_diagonal_distance_is_normalized(camera, rig), "T-04.2 diagonal movement has no speed increase")
	_expect(_movement_preserves_height(camera, rig), "T-04.3 WASD does not change camera Y")
	_expect(_screen_up_is_stable_after_full_turn(camera, rig), "T-04.4 screen direction remains stable through a full azimuth turn")

	_expect(await _orbit_uses_clicked_world_pivot(camera, rig, router), "T-05.1 drag orbits around the clicked 3D point")
	_expect(_orbit_moves_opposite_horizontal_cursor_delta(camera, rig), "T-05.2 horizontal orbit moves opposite cursor delta")
	_expect(_orbit_pivot_stays_fixed(camera, rig), "T-05.3 orbit pivot does not change during a gesture")
	_expect(await _click_does_not_move_camera(camera, rig, router), "T-05.4 click without drag does not move camera")
	_expect(_orbit_does_not_go_below_ground(camera, rig), "T-05.5 orbit keeps the camera at or above Y=0")

	_expect(_zoom_moves_in_and_out(camera, rig), "T-06.1 wheel zoom moves camera in both directions")
	_expect(_ground_zoom_respects_minimum_height(camera, rig), "T-06.2 ground zoom keeps camera Y at least 2")
	_expect(_module_zoom_respects_minimum_height(camera, rig), "T-06.3 module zoom keeps camera Y at least 3")
	_expect(_rapid_zoom_stays_safe(camera, rig), "T-06.4 rapid zoom preserves safety limits")
	_expect(_module_zoom_does_not_enter_fixture(camera, rig), "T-06.5 zoom does not enter the target module")
	_finish()

func _set_azimuth(camera: Camera3D, angle: float, target: Vector3 = FOCUS) -> void:
	camera.global_position = target + Vector3(cos(angle) * 32.0, 24.0, sin(angle) * 32.0)
	camera.look_at(target, Vector3.UP)

func _flat_forward(camera: Camera3D) -> Vector3:
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()

func _screen_directions_hold_at_four_azimuths(camera: Camera3D, rig: CameraRig3D) -> bool:
	for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		_set_azimuth(camera, angle)
		var forward := _flat_forward(camera)
		var right := camera.global_transform.basis.x
		right.y = 0.0
		right = right.normalized()
		var checks := [
			[Vector2(0.0, 1.0), forward],
			[Vector2(0.0, -1.0), -forward],
			[Vector2.RIGHT, right],
			[Vector2.LEFT, -right],
		]
		for check: Array in checks:
			var before := camera.global_position
			rig.move_screen_relative(check[0], 1.0)
			var motion := (camera.global_position - before).normalized()
			if motion.dot(check[1]) < 0.999:
				return false
	return true

func _diagonal_distance_is_normalized(camera: Camera3D, rig: CameraRig3D) -> bool:
	_set_azimuth(camera, 0.7)
	var before := camera.global_position
	rig.move_screen_relative(Vector2(0.0, 1.0), 1.0)
	var straight_distance := camera.global_position.distance_to(before)
	_set_azimuth(camera, 0.7)
	before = camera.global_position
	for _index in 4:
		rig.move_screen_relative(Vector2(0.0, 1.0), 0.25)
	var frame_independent_distance := camera.global_position.distance_to(before)
	_set_azimuth(camera, 0.7)
	before = camera.global_position
	rig.move_screen_relative(Vector2(1.0, 1.0), 1.0)
	return is_equal_approx(frame_independent_distance, straight_distance) and is_equal_approx(camera.global_position.distance_to(before), straight_distance)

func _movement_preserves_height(camera: Camera3D, rig: CameraRig3D) -> bool:
	_set_azimuth(camera, 1.2)
	var original_y := camera.global_position.y
	rig.move_screen_relative(Vector2(-1.0, 1.0), 0.75)
	return is_equal_approx(camera.global_position.y, original_y)

func _screen_up_is_stable_after_full_turn(camera: Camera3D, rig: CameraRig3D) -> bool:
	for angle: float in [0.0, TAU * 0.25, TAU * 0.5, TAU * 0.75, TAU]:
		_set_azimuth(camera, angle)
		var expected := _flat_forward(camera)
		var before := camera.global_position
		rig.move_screen_relative(Vector2(0.0, 1.0), 1.0)
		if (camera.global_position - before).normalized().dot(expected) < 0.999:
			return false
	return true

func _orbit_uses_clicked_world_pivot(camera: Camera3D, rig: CameraRig3D, router: InputRouter) -> bool:
	_set_azimuth(camera, 0.0, BELT_TOP)
	var screen_position := camera.unproject_position(BELT_TOP)
	router.route_world_event(_mouse_button(screen_position, true))
	await physics_frame
	if not rig.has_orbit_pivot or rig.orbit_pivot.distance_to(FOCUS) < 1.0:
		return false
	var original_distance := camera.global_position.distance_to(rig.orbit_pivot)
	var threshold_motion := InputEventMouseMotion.new()
	threshold_motion.position = screen_position + Vector2(rig.drag_threshold + 1.0, 0.0)
	router.route_world_event(threshold_motion)
	if rig.drag_state != CameraRig3D.DragState.ORBIT_DRAG:
		return false
	var before := camera.global_position
	var orbit_motion := InputEventMouseMotion.new()
	orbit_motion.position = threshold_motion.position + Vector2(20.0, 0.0)
	orbit_motion.relative = Vector2(20.0, 0.0)
	router.route_world_event(orbit_motion)
	await physics_frame
	router.route_world_event(_mouse_button(orbit_motion.position, false))
	return not camera.global_position.is_equal_approx(before) and is_equal_approx(camera.global_position.distance_to(rig.orbit_pivot), original_distance)

func _orbit_moves_opposite_horizontal_cursor_delta(camera: Camera3D, rig: CameraRig3D) -> bool:
	_set_azimuth(camera, 0.5)
	var pivot := Vector3(20.5, 0.0, 20.5)
	rig.begin_orbit_at(pivot)
	var before := camera.global_position - pivot
	rig.update_orbit(Vector2(20.0, 0.0))
	var after := camera.global_position - pivot
	return Vector3.UP.dot(before.cross(after)) < 0.0

func _orbit_pivot_stays_fixed(camera: Camera3D, rig: CameraRig3D) -> bool:
	_set_azimuth(camera, 1.0)
	var pivot := Vector3(12.0, 0.0, 18.0)
	rig.begin_orbit_at(pivot)
	rig.update_orbit(Vector2(10.0, -4.0))
	rig.update_orbit(Vector2(-3.0, 7.0))
	return rig.orbit_pivot.is_equal_approx(pivot)

func _click_does_not_move_camera(camera: Camera3D, rig: CameraRig3D, router: InputRouter) -> bool:
	_set_azimuth(camera, 0.0)
	var before := camera.global_transform
	var screen_position := camera.unproject_position(FOCUS)
	router.route_world_event(_mouse_button(screen_position, true))
	await physics_frame
	router.route_world_event(_mouse_button(screen_position, false))
	return camera.global_transform.is_equal_approx(before)

func _mouse_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	return event

func _orbit_does_not_go_below_ground(camera: Camera3D, rig: CameraRig3D) -> bool:
	var pivot := Vector3(20.5, 0.0, 20.5)
	camera.global_position = pivot + Vector3(5.0, 0.1, 5.0)
	camera.look_at(pivot, Vector3.UP)
	rig.begin_orbit_at(pivot)
	rig.update_orbit(Vector2(0.0, 1000.0))
	return camera.global_position.y >= 0.0

func _zoom_moves_in_and_out(camera: Camera3D, rig: CameraRig3D) -> bool:
	_set_azimuth(camera, 0.0)
	var screen_position := camera.unproject_position(FOCUS)
	var before := camera.global_position.distance_to(FOCUS)
	rig.zoom(1.0, screen_position)
	var closer := camera.global_position.distance_to(FOCUS)
	rig.zoom(-1.0, screen_position)
	return closer < before and camera.global_position.distance_to(FOCUS) > closer

func _ground_zoom_respects_minimum_height(camera: Camera3D, rig: CameraRig3D) -> bool:
	_set_azimuth(camera, 0.0)
	var screen_position := camera.unproject_position(FOCUS)
	for _index in 20:
		rig.zoom(1.0, screen_position)
	return camera.global_position.y >= 2.0

func _module_zoom_respects_minimum_height(camera: Camera3D, rig: CameraRig3D) -> bool:
	_set_azimuth(camera, 0.0, BELT_TOP)
	var screen_position := camera.unproject_position(BELT_TOP)
	for _index in 20:
		rig.zoom(1.0, screen_position)
	return camera.global_position.y >= 3.0

func _rapid_zoom_stays_safe(camera: Camera3D, rig: CameraRig3D) -> bool:
	_set_azimuth(camera, 0.0, BELT_TOP)
	var screen_position := camera.unproject_position(BELT_TOP)
	for _index in 100:
		rig.zoom(1.0, screen_position)
		rig.zoom(-1.0, screen_position)
	return camera.global_position.is_finite() and camera.global_position.y >= 3.0

func _module_zoom_does_not_enter_fixture(camera: Camera3D, rig: CameraRig3D) -> bool:
	_set_azimuth(camera, 0.0, BELT_TOP)
	var screen_position := camera.unproject_position(BELT_TOP)
	for _index in 40:
		rig.zoom(1.0, screen_position)
	return camera.global_position.y >= BELT_TOP.y + 2.0

func _expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	print("P4_TEST_RESULT: PASS %d / FAIL %d" % [passed, failed])
	quit(0 if failed == 0 else 1)
