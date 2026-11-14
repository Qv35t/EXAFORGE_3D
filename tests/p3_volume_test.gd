extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: Node3D = MAIN_SCENE.instantiate() as Node3D
	root.add_child(world)
	await physics_frame

	var area: ConstructionArea = world.get_node_or_null("ConstructionArea") as ConstructionArea
	var fixtures: TestFixtures = world.get_node_or_null("TestFixtures") as TestFixtures
	var camera: Camera3D = world.get_node_or_null("Camera3D") as Camera3D
	var camera_position: Vector3 = camera.position if camera != null else Vector3.INF
	var camera_rotation: Vector3 = camera.rotation if camera != null else Vector3.INF

	_expect(_fixture_occupies_one_cell(fixtures, "TestBelt", TestFixtures.BELT_CELL, "belt"), "T-03.1 test belt occupies one logical 1x1x1 cell")
	_expect(_fixture_occupies_one_cell(fixtures, "TestPipe", TestFixtures.PIPE_CELL, "pipe"), "T-03.2 test pipe occupies one logical 1x1x1 cell")

	var fixture_count: int = fixtures.grid.occupancy_count() if fixtures != null and fixtures.grid != null else -1
	var duplicate_rejected := fixtures != null and fixtures.grid != null and not fixtures.grid.occupy(TestFixtures.BELT_CELL, "pipe")
	_expect(duplicate_rejected and fixtures.grid.occupancy_count() == fixture_count and fixtures.grid.occupant_type(TestFixtures.BELT_CELL) == "belt", "T-03.3 incompatible modules cannot share one volume")

	var neighbor_grid := ModuleGrid3D.new(area)
	_expect(neighbor_grid.occupy(Vector3i(4, 0, 4), "belt") and neighbor_grid.occupy(Vector3i(5, 0, 4), "pipe"), "T-03.4 neighboring non-overlapping volumes are valid")

	var levels_grid := ModuleGrid3D.new(area)
	_expect(levels_grid.occupy(Vector3i(6, 0, 6), "belt") and levels_grid.occupy(Vector3i(6, 1, 6), "pipe"), "T-03.5 Y participates in occupancy")

	_expect(_has_unit_box(world, "TestFixtures/TestBelt") and _has_unit_box(world, "TestFixtures/TestPipe"), "T-03.6 unit volumes have exact 1x1x1 geometry")
	var coordinate := Vector3i(63, 1, 0)
	_expect(ModuleGrid3D.world_to_cell(ModuleGrid3D.cell_to_world(coordinate)) == coordinate, "T-03.7 cell and world coordinates round-trip")
	_expect(_has_base_lower_face(world, "TestFixtures/TestBelt"), "T-03.8 base volume lower face is Y=0")
	_expect(area != null and area.contains_volume_cell(Vector3i(0, 0, 0)) and area.contains_volume_cell(Vector3i(63, 0, 63)), "T-03.9 construction corners are valid")
	_expect(area != null and not area.contains_volume_cell(Vector3i(-1, 0, 0)) and not area.contains_volume_cell(Vector3i(64, 0, 0)) and not area.contains_volume_cell(Vector3i(0, 0, -1)) and not area.contains_volume_cell(Vector3i(0, 0, 64)), "T-03.10 out-of-bounds X/Z cells are rejected")

	var atomic_grid := ModuleGrid3D.new(area)
	var atomic_cell := Vector3i(8, 0, 8)
	var first_placement := atomic_grid.occupy(atomic_cell, "belt")
	var rejected_placement := not atomic_grid.occupy(atomic_cell, "pipe")
	_expect(first_placement and rejected_placement and atomic_grid.occupancy_count() == 1 and atomic_grid.occupant_type(atomic_cell) == "belt", "T-03.11 duplicate placement does not mutate occupancy")

	var adjacent_grid := ModuleGrid3D.new(area)
	_expect(adjacent_grid.occupy(Vector3i(9, 0, 9), "belt") and adjacent_grid.can_occupy(Vector3i(10, 0, 9)), "T-03.12 neighboring free cell remains available")

	var vertical_grid := ModuleGrid3D.new(area)
	_expect(vertical_grid.occupy(Vector3i(11, 0, 11), "belt") and vertical_grid.occupy(Vector3i(11, 2, 11), "pipe") and vertical_grid.occupancy_count() == 2, "T-03.13 valid Y levels have independent occupancy")

	var release_grid := ModuleGrid3D.new(area)
	var released_cell := Vector3i(12, 0, 12)
	var retained_cell := Vector3i(13, 0, 12)
	release_grid.occupy(released_cell, "belt")
	release_grid.occupy(retained_cell, "pipe")
	_expect(release_grid.release(released_cell) and not release_grid.is_occupied(released_cell) and release_grid.is_occupied(retained_cell), "T-03.14 release frees only the requested cell")

	_expect(ModuleGrid3D.world_to_cell(Vector3(-0.001, -0.001, -1.0)) == Vector3i(-1, -1, -1) and ModuleGrid3D.world_to_cell(Vector3(0.999, 0.999, 63.999)) == Vector3i(0, 0, 63), "T-03.15 world conversion floors negative and boundary positions")
	_expect(_fixture_geometry_matches_collision(world, "TestFixtures/TestBelt") and _fixture_geometry_matches_collision(world, "TestFixtures/TestPipe"), "T-03.16 visual and physical unit-volume fixtures agree")

	await process_frame
	_expect(camera != null and camera.position.is_equal_approx(camera_position) and camera.rotation.is_equal_approx(camera_rotation) and area != null and area.width == 64 and area.depth == 64, "T-03.17 camera remains static and P2 territory size is unchanged")
	_finish()

func _fixture_occupies_one_cell(fixtures: TestFixtures, fixture_name: String, cell: Vector3i, module_type: String) -> bool:
	if fixtures == null or fixtures.grid == null:
		return false
	var fixture: Node3D = fixtures.get_node_or_null(fixture_name) as Node3D
	return fixture != null and fixture.position.is_equal_approx(ModuleGrid3D.cell_to_world(cell)) and fixtures.grid.is_occupied(cell) and fixtures.grid.occupant_type(cell) == module_type

func _has_unit_box(world: Node3D, path: String) -> bool:
	var mesh_instance: MeshInstance3D = world.get_node_or_null("%s/MeshInstance3D" % path) as MeshInstance3D
	return mesh_instance != null and mesh_instance.mesh is BoxMesh and (mesh_instance.mesh as BoxMesh).size.is_equal_approx(Vector3.ONE)

func _has_base_lower_face(world: Node3D, path: String) -> bool:
	var fixture: Node3D = world.get_node_or_null(path) as Node3D
	var mesh_instance: MeshInstance3D = world.get_node_or_null("%s/MeshInstance3D" % path) as MeshInstance3D
	if fixture == null or mesh_instance == null or not mesh_instance.mesh is BoxMesh:
		return false
	return is_equal_approx(fixture.position.y - (mesh_instance.mesh as BoxMesh).size.y * 0.5, 0.0)

func _fixture_geometry_matches_collision(world: Node3D, path: String) -> bool:
	var mesh_instance: MeshInstance3D = world.get_node_or_null("%s/MeshInstance3D" % path) as MeshInstance3D
	var collision: CollisionShape3D = world.get_node_or_null("%s/StaticBody3D/CollisionShape3D" % path) as CollisionShape3D
	if mesh_instance == null or collision == null or not mesh_instance.mesh is BoxMesh or not collision.shape is BoxShape3D:
		return false
	return (mesh_instance.mesh as BoxMesh).size.is_equal_approx((collision.shape as BoxShape3D).size)

func _expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	print("P3_TEST_RESULT: PASS %d / FAIL %d" % [passed, failed])
	quit(0 if failed == 0 else 1)
