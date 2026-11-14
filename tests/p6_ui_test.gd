extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := MAIN_SCENE.instantiate() as Node3D
	root.add_child(world)
	var router := world.get_node_or_null("InputRouter") as InputRouter
	var ui := world.get_node_or_null("GameUi") as GameUi
	_expect(ui != null and router != null, "P6 setup exposes GameUi and InputRouter")
	if ui == null or router == null:
		_finish()
		return

	_expect(ui.loading_screen.visible and not ui.game_view.visible and not router.enabled, "P6-UI-01 loading state blocks input before readiness")
	await process_frame
	await process_frame
	_expect(not ui.loading_screen.visible and ui.game_view.visible and router.enabled, "P6-UI-02 loading state completes with world and input ready")
	_expect(ui.hint_row.get_child_count() == 3, "P6-UI-03 bottom HUD contains three control hint groups")
	_expect(is_equal_approx(ui.hint_row.modulate.a, 0.5) and _find_mouse_icon(ui.hint_row) != null, "P6-UI-04 HUD uses one 50 percent alpha group and a drawn mouse wheel")

	ui.controls_button.emit_signal("pressed")
	_expect(ui.is_controls_open() and router.modal_ui_active and router.ui_mouse_blocked and router.ui_keyboard_blocked, "P6-UI-05 controls button opens a modal input-blocking overlay")
	_expect(ui.controls_tabs.get_tab_title(0) == "Камера" and ui.controls_tabs.get_tab_title(1) == "Игровое пространство", "P6-UI-06 controls tabs describe verified camera and game-space content")
	_expect(ui.controls_tabs.is_tab_disabled(2), "P6-UI-07 settings tab remains visibly disabled")
	_expect(_modal_blocks_world_input(world, router), "P6-UI-08 modal blocks camera keyboard pointer and wheel input")
	_expect(_escape_closes_modal(ui, router), "P6-UI-09 InputRouter Esc closes the overlay and clears capture")
	_expect(_responsive_minimums_fit(ui), "P6-UI-10 controls layout minimums fit 1280x720 and 1920x1080")
	_finish()

func _modal_blocks_world_input(world: Node3D, router: InputRouter) -> bool:
	var camera := world.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return false
	var before := camera.global_transform
	var position := camera.unproject_position(Vector3(32.0, 0.0, 32.0))
	router._input(_key(KEY_W, true))
	router._process(1.0)
	router._input(_wheel(position, MOUSE_BUTTON_WHEEL_UP))
	router._input(_left_button(position, true))
	return camera.global_transform.is_equal_approx(before) and router.gesture_state == InputRouter.GestureState.IDLE and router.pressed_keys.is_empty()

func _escape_closes_modal(ui: GameUi, router: InputRouter) -> bool:
	router._input(_key(KEY_ESCAPE, true))
	return not ui.is_controls_open() and not router.modal_ui_active and not router.ui_mouse_blocked and not router.ui_keyboard_blocked and router.gesture_state == InputRouter.GestureState.IDLE

func _responsive_minimums_fit(ui: GameUi) -> bool:
	var panel := ui.controls_overlay.get_node_or_null("ControlsCenter/ControlsModal") as PanelContainer
	if panel == null:
		return false
	var margins := Vector2(56.0, 44.0)
	var small_viewport := Vector2(1280.0, 720.0)
	var large_viewport := Vector2(1920.0, 1080.0)
	return panel.custom_minimum_size.x + margins.x <= small_viewport.x and panel.custom_minimum_size.y + margins.y <= small_viewport.y and panel.custom_minimum_size.x + margins.x <= large_viewport.x and panel.custom_minimum_size.y + margins.y <= large_viewport.y

func _find_mouse_icon(node: Node) -> MouseWheelIcon:
	if node is MouseWheelIcon:
		return node as MouseWheelIcon
	for child in node.get_children():
		var icon := _find_mouse_icon(child)
		if icon != null:
			return icon
	return null

func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	return event

func _wheel(position: Vector2, button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = position
	event.pressed = true
	return event

func _left_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	return event

func _expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	print("P6_TEST_RESULT: PASS %d / FAIL %d" % [passed, failed])
	quit(0 if failed == 0 else 1)
