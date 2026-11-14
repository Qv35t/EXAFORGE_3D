extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: Node3D = MAIN_SCENE.instantiate() as Node3D
	root.add_child(world)
	await physics_frame

	var camera: Camera3D = world.get_node_or_null("Camera3D") as Camera3D
	var surface: MeshInstance3D = world.get_node_or_null("ConstructionSurface") as MeshInstance3D
	var reference_body: StaticBody3D = world.get_node_or_null("ReferenceVolume/StaticBody3D") as StaticBody3D

	_expect(camera != null and camera.current, "T-01.1 Camera3D is present and current")
	_expect(surface != null and surface.mesh is PlaneMesh, "T-01.1 construction surface is a 3D PlaneMesh")
	_expect(reference_body != null, "T-01.1 reference volume has a 3D physics body")
	_expect(_is_reference_volume_3d(world), "T-01.2 reference volume is a 1x1x1 BoxMesh with visible spatial faces")

	if camera != null:
		_expect(_ray_hits(camera, Vector3(44.0, 0.0, 40.0), world.get_node("ConstructionSurfaceCollider")), "T-01.3 camera ray hits the 3D construction surface")
		_expect(_ray_hits(camera, Vector3(18.0, 0.5, 18.0), reference_body), "T-01.3 camera ray hits the 3D reference volume")

	if failures.is_empty():
		print("P1_TEST_RESULT: PASS 6 / FAIL 0")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("P1_TEST_RESULT: PASS %d / FAIL %d" % [6 - failures.size(), failures.size()])
		quit(1)

func _is_reference_volume_3d(world: Node3D) -> bool:
	var mesh_instance: MeshInstance3D = world.get_node_or_null("ReferenceVolume/MeshInstance3D") as MeshInstance3D
	if mesh_instance == null or not mesh_instance.mesh is BoxMesh:
		return false
	var box: BoxMesh = mesh_instance.mesh as BoxMesh
	return box.size.is_equal_approx(Vector3.ONE)

func _ray_hits(camera: Camera3D, point: Vector3, expected_collider: CollisionObject3D) -> bool:
	var screen_point: Vector2 = camera.unproject_position(point)
	var origin: Vector3 = camera.project_ray_origin(screen_point)
	var end: Vector3 = origin + camera.project_ray_normal(screen_point) * 250.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	var result: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(query)
	return result.get("collider") == expected_collider

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append("FAIL: %s" % message)
