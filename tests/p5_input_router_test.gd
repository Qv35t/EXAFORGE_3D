extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const FOCUS := Vector3(32.0, 0.0, 32.0)
const BELT_TOP := Vector3(20.5, 1.0, 20.5)

var passed := 0
var failed := 0
var world_click_count := 0
var last_world_click: Variant = null

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
		_expect(false, "P5 setup exposes Camera3D, CameraRig3D, and InputRouter")
		_finish()
		return
	router.world_click.connect(_on_world_click)

	_expect(await _short_click_emits_once(camera, router), "T-07.1 short world click does not orbit and emits once")
	_expect(await _subthreshold_motion_stays_click(camera, router), "P5-INT-02 subthreshold motion emits one click without orbit")
	_expect(await _drag_orbits_without_click(camera, rig, router), "T-07.2 drag orbits and emits no click")
	_expect(await _drag_keeps_initial_pivot(camera, rig, router), "P5-INT-04 drag keeps its initial ray-picked pivot")
	_expect(_ui_click_and_drag_are_ignored(camera, rig, router), "T-07.3 UI click and drag do not reach world or camera")
	_expect(_ui_wheel_does_not_zoom(camera, router), "T-07.5 UI scroll does not zoom camera")
	_expect(await _text_focus_blocks_wasd(world, camera, router), "P5-INT-07 text focus blocks WASD")
	_expect(_world_focus_allows_wasd(camera, router), "P5-INT-08 world focus preserves screen-relative WASD")
	_expect(_focus_change_clears_held_keys(camera, router), "P5-INT-09 focus change clears held movement")
	_expect(await _focus_out_cancels_drag(camera, rig, router), "T-07.4 focus out cancels drag without restoring it")
	_expect(await _world_capture_finishes_over_ui(camera, router), "P5-INT-11 world capture receives release over UI")
	_expect(await _rapid_input_has_no_stale_click_or_pivot(camera, rig, router), "P5-INT-12 rapid input has no duplicate click or stale pivot")
	_expect(_disabling_router_clears_all_state(camera, rig, router), "P5-INT-13 disabling router clears capture and keys")
	_finish()

func _set_camera(camera: Camera3D, target: Vector3 = FOCUS) -> void:
	camera.global_position = target + Vector3(32.0, 24.0, 0.0)
	camera.look_at(target, Vector3.UP)

func _reset(router: InputRouter) -> void:
	router.set_enabled(true)
	router.set_ui_mouse_blocked(false)
	router.set_ui_keyboard_blocked(false)
	router.cancel_input()
	world_click_count = 0
	last_world_click = null

func _short_click_emits_once(camera: Camera3D, router: InputRouter) -> bool:
	_reset(router)
	_set_camera(camera)
	var screen_position := camera.unproject_position(FOCUS)
	var before := camera.global_transform
	router.route_world_event(_left_button(screen_position, true))
	await physics_frame
	router.route_world_event(_left_button(screen_position, false))
	return world_click_count == 1 and last_world_click != null and camera.global_transform.is_equal_approx(before)

func _subthreshold_motion_stays_click(camera: Camera3D, router: InputRouter) -> bool:
	_reset(router)
	_set_camera(camera)
	var screen_position := camera.unproject_position(FOCUS)
	var before := camera.global_transform
	router.route_world_event(_left_button(screen_position, true))
	await physics_frame
	router.route_world_event(_motion(screen_position + Vector2(router.camera_rig.drag_threshold - 1.0, 0.0), Vector2(1.0, 0.0)))
	router.route_world_event(_left_button(screen_position, false))
	return world_click_count == 1 and router.gesture_state == InputRouter.GestureState.IDLE and camera.global_transform.is_equal_approx(before)

func _drag_orbits_without_click(camera: Camera3D, rig: CameraRig3D, router: InputRouter) -> bool:
	_reset(router)
	_set_camera(camera, BELT_TOP)
	var screen_position := camera.unproject_position(BELT_TOP)
	router.route_world_event(_left_button(screen_position, true))
	await physics_frame
	var before := camera.global_position
	router.route_world_event(_motion(screen_position + Vector2(rig.drag_threshold + 1.0, 0.0), Vector2.ZERO))
	router.route_world_event(_motion(screen_position + Vector2(rig.drag_threshold + 21.0, 0.0), Vector2(20.0, 0.0)))
	await physics_frame
	router.route_world_event(_left_button(screen_position, false))
	return world_click_count == 0 and not camera.global_position.is_equal_approx(before) and router.gesture_state == InputRouter.GestureState.IDLE

func _drag_keeps_initial_pivot(camera: Camera3D, rig: CameraRig3D, router: InputRouter) -> bool:
	_reset(router)
	_set_camera(camera, BELT_TOP)
	var screen_position := camera.unproject_position(BELT_TOP)
	router.route_world_event(_left_button(screen_position, true))
	await physics_frame
	var pivot := rig.orbit_pivot
	router.route_world_event(_motion(screen_position + Vector2(rig.drag_threshold + 1.0, 0.0), Vector2.ZERO))
	router.route_world_event(_motion(screen_position + Vector2(rig.drag_threshold + 31.0, 9.0), Vector2(30.0, 9.0)))
	await physics_frame
	var unchanged := rig.orbit_pivot.is_equal_approx(pivot)
	router.route_world_event(_left_button(screen_position, false))
	return unchanged

func _ui_click_and_drag_are_ignored(camera: Camera3D, rig: CameraRig3D, router: InputRouter) -> bool:
	_reset(router)
	_set_camera(camera)
	var before := camera.global_transform
	router.set_ui_mouse_blocked(true)
	var screen_position := camera.unproject_position(FOCUS)
	router._input(_left_button(screen_position, true))
	router._input(_motion(screen_position + Vector2(30.0, 0.0), Vector2(30.0, 0.0)))
	router._input(_left_button(screen_position, false))
	router.set_ui_mouse_blocked(false)
	return world_click_count == 0 and router.gesture_state == InputRouter.GestureState.IDLE and rig.drag_state == CameraRig3D.DragState.IDLE and camera.global_transform.is_equal_approx(before)

func _ui_wheel_does_not_zoom(camera: Camera3D, router: InputRouter) -> bool:
	_reset(router)
	_set_camera(camera)
	var before := camera.global_position
	router.set_ui_mouse_blocked(true)
	router._input(_wheel(camera.unproject_position(FOCUS), MOUSE_BUTTON_WHEEL_UP))
	router.set_ui_mouse_blocked(false)
	return camera.global_position.is_equal_approx(before)

func _text_focus_blocks_wasd(world: Node3D, camera: Camera3D, router: InputRouter) -> bool:
	_reset(router)
	_set_camera(camera)
	var text_field := LineEdit.new()
	world.add_child(text_field)
	text_field.grab_focus()
	await process_frame
	var before := camera.global_position
	router._input(_key(KEY_W, true))
	router._process(1.0)
	text_field.release_focus()
	text_field.queue_free()
	return camera.global_position.is_equal_approx(before)

func _world_focus_allows_wasd(camera: Camera3D, router: InputRouter) -> bool:
	_reset(router)
	_set_camera(camera)
	var before := camera.global_position
	router._input(_key(KEY_W, true))
	router._process(1.0)
	router._input(_key(KEY_W, false))
	return not camera.global_position.is_equal_approx(before)

func _focus_change_clears_held_keys(camera: Camera3D, router: InputRouter) -> bool:
	_reset(router)
	_set_camera(camera)
	router._input(_key(KEY_W, true))
	router._process(0.5)
	router.set_ui_keyboard_blocked(true)
	var before := camera.global_position
	router._process(1.0)
	router.set_ui_keyboard_blocked(false)
	return camera.global_position.is_equal_approx(before) and router.pressed_keys.is_empty()

func _focus_out_cancels_drag(camera: Camera3D, rig: CameraRig3D, router: InputRouter) -> bool:
	_reset(router)
	_set_camera(camera, BELT_TOP)
	var screen_position := camera.unproject_position(BELT_TOP)
	router.route_world_event(_left_button(screen_position, true))
	await physics_frame
	router.route_world_event(_motion(screen_position + Vector2(rig.drag_threshold + 1.0, 0.0), Vector2.ZERO))
	router.route_world_event(_motion(screen_position + Vector2(rig.drag_threshold + 21.0, 0.0), Vector2(20.0, 0.0)))
	router._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var before := camera.global_transform
	await physics_frame
	return router.gesture_state == InputRouter.GestureState.IDLE and rig.drag_state == CameraRig3D.DragState.IDLE and camera.global_transform.is_equal_approx(before)

func _world_capture_finishes_over_ui(camera: Camera3D, router: InputRouter) -> bool:
	_reset(router)
	_set_camera(camera)
	var screen_position := camera.unproject_position(FOCUS)
	router.route_world_event(_left_button(screen_position, true))
	router.set_ui_mouse_blocked(true)
	router._input(_left_button(screen_position, false))
	router.set_ui_mouse_blocked(false)
	return world_click_count == 1 and router.gesture_state == InputRouter.GestureState.IDLE

func _rapid_input_has_no_stale_click_or_pivot(camera: Camera3D, rig: CameraRig3D, router: InputRouter) -> bool:
	_reset(router)
	_set_camera(camera)
	var screen_position := camera.unproject_position(FOCUS)
	for _index in 8:
		router.route_world_event(_left_button(screen_position, true))
		router.route_world_event(_left_button(screen_position, false))
	await physics_frame
	return world_click_count == 8 and router.gesture_state == InputRouter.GestureState.IDLE and rig.drag_state == CameraRig3D.DragState.IDLE and not rig.pending_pivot_pick

func _disabling_router_clears_all_state(camera: Camera3D, rig: CameraRig3D, router: InputRouter) -> bool:
	_reset(router)
	_set_camera(camera)
	var screen_position := camera.unproject_position(FOCUS)
	router._input(_key(KEY_W, true))
	router.route_world_event(_left_button(screen_position, true))
	router.set_enabled(false)
	var cleared := router.gesture_state == InputRouter.GestureState.IDLE and router.pressed_keys.is_empty() and rig.drag_state == CameraRig3D.DragState.IDLE and not rig.pending_pivot_pick
	router.set_enabled(true)
	return cleared

func _left_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	return event

func _wheel(position: Vector2, button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = position
	event.pressed = true
	return event

func _motion(position: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = relative
	return event

func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	return event

func _on_world_click(_screen_position: Vector2, world_position: Variant) -> void:
	world_click_count += 1
	last_world_click = world_position

func _expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	print("P5_TEST_RESULT: PASS %d / FAIL %d" % [passed, failed])
	quit(0 if failed == 0 else 1)
