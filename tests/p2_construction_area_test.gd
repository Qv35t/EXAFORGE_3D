extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: Node3D = MAIN_SCENE.instantiate() as Node3D
	root.add_child(world)
	await process_frame

	var area: ConstructionArea = world.get_node_or_null("ConstructionArea") as ConstructionArea
	var camera: Camera3D = world.get_node_or_null("Camera3D") as Camera3D
	if area == null or camera == null:
		_expect(false, "P2 setup exposes ConstructionArea and Camera3D")
		_finish()
		return

	_expect(area.cell_count() == 4096 and area.contains_base_cell(0, 0, 0), "T-02.1 base layer contains exactly 4096 addressable cells")
	_expect(area.contains_cell(0, 0) and area.contains_cell(63, 63), "T-02.2 inclusive construction boundaries are valid")
	_expect(not area.contains_cell(-1, 0) and not area.contains_cell(64, 0) and not area.contains_cell(0, -1) and not area.contains_cell(0, 64), "T-02.3 adjacent out-of-bounds coordinates are rejected")
	_expect(_has_separate_environment(world, area), "T-02.4 visible environment remains separate from construction area")

	var before: Array[bool] = _boundary_signature(area)
	camera.rotate_y(PI * 0.5)
	var after: Array[bool] = _boundary_signature(area)
	_expect(before == after, "T-02.5 camera orientation does not change construction coordinates")
	_finish()

func _has_separate_environment(world: Node3D, area: ConstructionArea) -> bool:
	var environment_surface: MeshInstance3D = world.get_node_or_null("EnvironmentRoot/EnvironmentSurface") as MeshInstance3D
	var construction_surface: MeshInstance3D = world.get_node_or_null("ConstructionSurface") as MeshInstance3D
	var environment_mesh: PlaneMesh = environment_surface.mesh as PlaneMesh if environment_surface != null else null
	var construction_mesh: PlaneMesh = construction_surface.mesh as PlaneMesh if construction_surface != null else null
	return environment_surface != null and construction_surface != null and environment_surface.visible and construction_surface.visible and environment_mesh != null and construction_mesh != null and environment_mesh.size == Vector2(80.0, 80.0) and construction_mesh.size == Vector2(64.0, 64.0) and not area.contains_cell(64, 32)

func _boundary_signature(area: ConstructionArea) -> Array[bool]:
	return [
		area.contains_cell(0, 0),
		area.contains_cell(63, 63),
		area.contains_cell(-1, 0),
		area.contains_cell(64, 0),
		area.contains_cell(0, -1),
		area.contains_cell(0, 64),
	]

func _expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	print("P2_TEST_RESULT: PASS %d / FAIL %d" % [passed, failed])
	quit(0 if failed == 0 else 1)
