class_name InputRouter
extends Node

signal world_click(screen_position: Vector2, world_position: Variant)

enum GestureState { IDLE, PRESS_PENDING, ORBIT_DRAG }

@export var camera_rig_path: NodePath = NodePath("../CameraRig3D")

@onready var camera_rig: CameraRig3D = get_node_or_null(camera_rig_path) as CameraRig3D

var gesture_state := GestureState.IDLE
var press_position := Vector2.ZERO
var pressed_keys: Dictionary = {}
var enabled := true
var ui_mouse_blocked := false
var ui_keyboard_blocked := false

func _process(delta: float) -> void:
	if camera_rig == null or not enabled or _keyboard_is_blocked():
		pressed_keys.clear()
		return
	var direction := Vector2(
		float(pressed_keys.has(KEY_D)) - float(pressed_keys.has(KEY_A)),
		float(pressed_keys.has(KEY_W)) - float(pressed_keys.has(KEY_S))
	)
	if not direction.is_zero_approx():
		camera_rig.move_screen_relative(direction, delta)

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventKey:
		if _keyboard_is_blocked():
			pressed_keys.clear()
			return
		if _route_key(event):
			get_viewport().set_input_as_handled()
		return
	if not _is_mouse_event(event):
		return
	if gesture_state == GestureState.IDLE and _ui_owns_pointer():
		return
	if route_world_event(event):
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_input()

func route_world_event(event: InputEvent) -> bool:
	if not enabled or camera_rig == null:
		return false
	if event is InputEventMouseButton:
		return _route_mouse_button(event)
	if event is InputEventMouseMotion:
		return _route_mouse_motion(event)
	return false

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		cancel_input()

func set_ui_mouse_blocked(value: bool) -> void:
	ui_mouse_blocked = value

func set_ui_keyboard_blocked(value: bool) -> void:
	ui_keyboard_blocked = value
	if value:
		pressed_keys.clear()

func cancel_input() -> void:
	pressed_keys.clear()
	gesture_state = GestureState.IDLE
	press_position = Vector2.ZERO
	if camera_rig != null:
		camera_rig.cancel_orbit()

func _route_key(event: InputEventKey) -> bool:
	if event.echo or not event.keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
		return false
	if event.pressed:
		pressed_keys[event.keycode] = true
	else:
		pressed_keys.erase(event.keycode)
	return true

func _route_mouse_button(event: InputEventMouseButton) -> bool:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			gesture_state = GestureState.PRESS_PENDING
			press_position = event.position
			camera_rig.begin_orbit(press_position)
		else:
			_finish_left_gesture()
		return true
	if not event.pressed or gesture_state == GestureState.ORBIT_DRAG:
		return false
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera_rig.zoom(1.0, event.position)
		return true
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera_rig.zoom(-1.0, event.position)
		return true
	return false

func _route_mouse_motion(event: InputEventMouseMotion) -> bool:
	if gesture_state == GestureState.IDLE:
		return false
	if gesture_state == GestureState.PRESS_PENDING and press_position.distance_to(event.position) >= camera_rig.drag_threshold:
		gesture_state = GestureState.ORBIT_DRAG
		camera_rig.request_orbit_drag()
	if gesture_state == GestureState.ORBIT_DRAG:
		camera_rig.queue_orbit_delta(event.relative)
	return true

func _finish_left_gesture() -> void:
	if gesture_state == GestureState.PRESS_PENDING:
		world_click.emit(press_position, camera_rig.pick_world_point(press_position))
	gesture_state = GestureState.IDLE
	press_position = Vector2.ZERO
	camera_rig.end_orbit()

func _keyboard_is_blocked() -> bool:
	if ui_keyboard_blocked:
		return true
	var focused_control := get_viewport().gui_get_focus_owner()
	return focused_control is LineEdit or focused_control is TextEdit or (focused_control != null and focused_control.is_in_group("blocks_game_input"))

func _ui_owns_pointer() -> bool:
	return ui_mouse_blocked or get_viewport().gui_get_hovered_control() != null

func _is_mouse_event(event: InputEvent) -> bool:
	return event is InputEventMouseButton or event is InputEventMouseMotion
