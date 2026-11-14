class_name CameraRig3D
extends Node3D

enum DragState { IDLE, PRESS_PENDING, ORBIT_DRAG }

@export var camera_path: NodePath = NodePath("../Camera3D")
@export_range(0.1, 100.0, 0.1) var move_speed := 20.0
@export_range(0.001, 0.1, 0.001) var orbit_sensitivity := 0.01
@export_range(0.1, 100.0, 0.1) var zoom_step := 4.0
@export_range(1.0, 32.0, 1.0) var drag_threshold := 5.0

@onready var camera: Camera3D = get_node_or_null(camera_path) as Camera3D

var drag_state := DragState.IDLE
var press_position := Vector2.ZERO
var orbit_pivot := Vector3.ZERO
var has_orbit_pivot := false
var pending_pivot_pick := false
var drag_requested := false
var pending_orbit_delta := Vector2.ZERO
var safe_focus_height := 0.0
var zoom_focus_position := Vector2.ZERO
var has_zoom_focus := false

func _process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		direction.y += 1.0
	if Input.is_key_pressed(KEY_S):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if not direction.is_zero_approx():
		move_screen_relative(direction, delta)

func _physics_process(_delta: float) -> void:
	if pending_pivot_pick:
		pending_pivot_pick = false
		var picked_pivot: Variant = _pick_pivot(press_position)
		if picked_pivot != null:
			orbit_pivot = picked_pivot as Vector3
			has_orbit_pivot = true
		if drag_requested and has_orbit_pivot:
			drag_state = DragState.ORBIT_DRAG
			pending_orbit_delta = Vector2.ZERO

	if drag_state == DragState.ORBIT_DRAG and not pending_orbit_delta.is_zero_approx():
		update_orbit(pending_orbit_delta)
		pending_orbit_delta = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				begin_orbit(event.position)
			else:
				end_orbit()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(1.0, event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(-1.0, event.position)
	elif event is InputEventMouseMotion:
		if drag_state == DragState.PRESS_PENDING:
			if press_position.distance_to(event.position) >= drag_threshold:
				if has_orbit_pivot:
					drag_state = DragState.ORBIT_DRAG
				else:
					drag_requested = true
		elif drag_state == DragState.ORBIT_DRAG:
			pending_orbit_delta += event.relative

func move_screen_relative(direction: Vector2, delta: float) -> void:
	if camera == null or direction.is_zero_approx():
		return
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.000001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var right := camera.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() <= 0.000001:
		right = forward.cross(Vector3.UP).normalized()
	else:
		right = right.normalized()
	var motion := (right * direction.x + forward * direction.y).normalized()
	camera.global_position += motion * move_speed * delta

func begin_orbit(screen_position: Vector2) -> void:
	if camera == null:
		return
	drag_state = DragState.PRESS_PENDING
	press_position = screen_position
	has_orbit_pivot = false
	pending_pivot_pick = true
	drag_requested = false
	pending_orbit_delta = Vector2.ZERO

func begin_orbit_at(pivot: Vector3) -> void:
	if camera == null:
		return
	orbit_pivot = pivot
	has_orbit_pivot = true
	drag_state = DragState.ORBIT_DRAG
	pending_pivot_pick = false
	drag_requested = false
	pending_orbit_delta = Vector2.ZERO

func update_orbit(mouse_delta: Vector2) -> void:
	if camera == null or drag_state != DragState.ORBIT_DRAG or not has_orbit_pivot:
		return

	var yaw_basis := Basis(Vector3.UP, -mouse_delta.x * orbit_sensitivity)
	camera.global_position = orbit_pivot + yaw_basis * (camera.global_position - orbit_pivot)
	camera.global_basis = yaw_basis * camera.global_basis

	var right_axis := camera.global_transform.basis.x.normalized()
	var pitch_basis := Basis(right_axis, -mouse_delta.y * orbit_sensitivity)
	var pitched_position := orbit_pivot + pitch_basis * (camera.global_position - orbit_pivot)
	if pitched_position.y >= 0.0:
		camera.global_position = pitched_position
		camera.global_basis = pitch_basis * camera.global_basis

func end_orbit() -> void:
	drag_state = DragState.IDLE
	has_orbit_pivot = false
	pending_pivot_pick = false
	drag_requested = false
	pending_orbit_delta = Vector2.ZERO

func zoom(scroll_step: float, screen_position: Vector2) -> void:
	if camera == null or is_zero_approx(scroll_step):
		return
	var hit_top: Variant = _surface_top_at(screen_position)
	if not has_zoom_focus or zoom_focus_position.distance_to(screen_position) > 1.0:
		has_zoom_focus = true
		zoom_focus_position = screen_position
		safe_focus_height = hit_top as float if hit_top != null else 0.0
	elif hit_top != null:
		# Do not lower the safety plane after a ray starts below its original target.
		safe_focus_height = maxf(safe_focus_height, hit_top as float)
	var candidate := camera.global_position + (-camera.global_transform.basis.z) * scroll_step * zoom_step
	var minimum_height := safe_focus_height + 2.0
	if candidate.y < minimum_height:
		candidate.y = minimum_height
	camera.global_position = candidate

func _pick_pivot(screen_position: Vector2) -> Variant:
	var hit: Dictionary = _raycast(screen_position)
	if not hit.is_empty():
		return hit.get("position")
	if camera == null:
		return null
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if is_zero_approx(direction.y):
		return null
	var distance := -origin.y / direction.y
	return origin + direction * distance if distance >= 0.0 else null

func _surface_top_at(screen_position: Vector2) -> Variant:
	var hit: Dictionary = _raycast(screen_position)
	return hit.get("position").y if not hit.is_empty() else null

func _raycast(screen_position: Vector2) -> Dictionary:
	if camera == null:
		return {}
	var origin := camera.project_ray_origin(screen_position)
	var end := origin + camera.project_ray_normal(screen_position) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	return get_world_3d().direct_space_state.intersect_ray(query)
