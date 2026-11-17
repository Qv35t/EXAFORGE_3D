extends SceneTree

const EPSILON := 0.0001
const OUTER_RADIUS := 0.09
const INNER_RADIUS := 0.07
const REPORT_DIRECTORY := "user://"
const ASSETS := {
	"Straight": preload("res://assets/models/pipes/EXAFORGE_Pipe_Straight.glb"),
	"Corner_90": preload("res://assets/models/pipes/EXAFORGE_Pipe_Corner_90.glb"),
	"Cross": preload("res://assets/models/pipes/EXAFORGE_Pipe_Cross.glb"),
	"T_Junction": preload("res://assets/models/pipes/EXAFORGE_Pipe_T_Junction.glb"),
}
const PORTS := {
	"Straight": {"WEST": Vector3(-0.5, 0.0, 0.0), "EAST": Vector3(0.5, 0.0, 0.0)},
	"Corner_90": {"NORTH": Vector3(0.0, 0.0, -0.5), "EAST": Vector3(0.5, 0.0, 0.0)},
	"Cross": {"WEST": Vector3(-0.5, 0.0, 0.0), "EAST": Vector3(0.5, 0.0, 0.0), "NORTH": Vector3(0.0, 0.0, -0.5), "SOUTH": Vector3(0.0, 0.0, 0.5)},
	"T_Junction": {"WEST": Vector3(-0.5, 0.0, 0.0), "EAST": Vector3(0.5, 0.0, 0.0), "NORTH": Vector3(0.0, 0.0, -0.5)},
}

var passed := 0
var failed := 0
var results: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for name in ASSETS:
		var asset := (ASSETS[name] as PackedScene).instantiate() as Node3D
		root.add_child(asset)
		await process_frame
		var bounds := _combined_bounds(asset)
		_expect(_fits_cell(bounds), "P7-PIPE-%s bounds fit the 1x1x1 cell" % name, {"bounds": _aabb_data(bounds)})
		_expect(_mesh_count(asset) > 0, "P7-PIPE-%s imports mesh geometry" % name, {"mesh_count": _mesh_count(asset)})
		_expect(_has_materials(asset), "P7-PIPE-%s imports materials" % name, {})
		for port_id in PORTS[name]:
			_expect(_has_actual_ring(asset, PORTS[name][port_id]), "P7-PIPE-%s %s boundary ring has OD 0.18 and ID 0.14" % [name, port_id], {"port": port_id})
		for angle in [0.0, 90.0, 180.0, 270.0]:
			asset.rotation_degrees.y = angle
			_expect(_fits_cell(_combined_bounds(asset)), "P7-PIPE-%s fits cell at %d degrees" % [name, angle], {"rotation": angle})
		asset.queue_free()
	for pair in [["Straight", "Straight"], ["Straight", "Corner_90"], ["Straight", "T_Junction"], ["Straight", "Cross"], ["Corner_90", "Corner_90"], ["Corner_90", "T_Junction"], ["Corner_90", "Cross"], ["T_Junction", "T_Junction"], ["T_Junction", "Cross"], ["Cross", "Cross"]]:
		_expect(await _validate_east_west_connection(pair[0], pair[1]), "P7-PIPE connection %s <-> %s" % [pair[0], pair[1]], {"pair": pair})
	_write_reports()
	print("P7_PIPE_VALIDATION_RESULT: PASS %d / FAIL %d" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _fits_cell(bounds: AABB) -> bool:
	return bounds.position.x >= -0.5 - EPSILON and bounds.position.y >= -0.5 - EPSILON and bounds.position.z >= -0.5 - EPSILON and bounds.end.x <= 0.5 + EPSILON and bounds.end.y <= 0.5 + EPSILON and bounds.end.z <= 0.5 + EPSILON


func _has_actual_ring(asset: Node3D, center: Vector3) -> bool:
	var vertices := _mesh_vertices(asset)
	var outer_found := false
	var inner_found := false
	for vertex in vertices:
		var delta := vertex - center
		var radial := 0.0
		if absf(center.x) > 0.49:
			if absf(vertex.x - center.x) > EPSILON:
				continue
			radial = Vector2(delta.y, delta.z).length()
		else:
			if absf(vertex.z - center.z) > EPSILON:
				continue
			radial = Vector2(delta.x, delta.y).length()
		outer_found = outer_found or is_equal_approx(radial, OUTER_RADIUS)
		inner_found = inner_found or is_equal_approx(radial, INNER_RADIUS)
	return outer_found and inner_found


func _validate_east_west_connection(first_name: String, second_name: String) -> bool:
	var first := (ASSETS[first_name] as PackedScene).instantiate() as Node3D
	var second := (ASSETS[second_name] as PackedScene).instantiate() as Node3D
	second.position.x = 1.0
	second.rotation.y = PI
	root.add_child(first)
	root.add_child(second)
	await process_frame
	var first_valid := _has_actual_ring(first, Vector3(0.5, 0.0, 0.0))
	var second_valid := _has_actual_ring(second, Vector3(0.5, 0.0, 0.0))
	var no_volume_overlap := _combined_bounds(first).end.x <= _combined_bounds(second).position.x + EPSILON
	first.queue_free()
	second.queue_free()
	return first_valid and second_valid and no_volume_overlap


func _combined_bounds(root_node: Node) -> AABB:
	var has_bounds := false
	var bounds := AABB()
	for mesh in _mesh_nodes(root_node):
		for corner in _aabb_corners(mesh.get_aabb()):
			var point := mesh.global_transform * corner
			if not has_bounds:
				bounds.position = point
				has_bounds = true
			else:
				bounds = bounds.expand(point)
	return bounds


func _mesh_vertices(root_node: Node) -> PackedVector3Array:
	var result := PackedVector3Array()
	for mesh_node in _mesh_nodes(root_node):
		if mesh_node.mesh == null:
			continue
		for surface in mesh_node.mesh.get_surface_count():
			var arrays := mesh_node.mesh.surface_get_arrays(surface)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				result.append(mesh_node.global_transform * vertex)
	return result


func _mesh_nodes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_mesh_nodes(child))
	return result


func _mesh_count(root_node: Node) -> int:
	return _mesh_nodes(root_node).size()


func _has_materials(root_node: Node) -> bool:
	for mesh_node in _mesh_nodes(root_node):
		if mesh_node.mesh != null and mesh_node.mesh.get_surface_count() > 0:
			return mesh_node.get_active_material(0) != null
	return false


func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for x in [aabb.position.x, aabb.end.x]:
		for y in [aabb.position.y, aabb.end.y]:
			for z in [aabb.position.z, aabb.end.z]:
				result.append(Vector3(x, y, z))
	return result


func _aabb_data(aabb: AABB) -> Dictionary:
	return {"min": [aabb.position.x, aabb.position.y, aabb.position.z], "max": [aabb.end.x, aabb.end.y, aabb.end.z]}


func _expect(condition: bool, label: String, detail: Dictionary) -> void:
	results.append({"label": label, "status": "PASS" if condition else "FAIL", "detail": detail})
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)


func _write_reports() -> void:
	var payload := {"status": "PASS" if failed == 0 else "VALIDATION_FAILED", "passed": passed, "failed": failed, "results": results}
	var json_file := FileAccess.open(REPORT_DIRECTORY.path_join("godot_pipe_validation.json"), FileAccess.WRITE)
	json_file.store_string(JSON.stringify(payload, "\t"))
	var markdown := "# Godot Pipe Validation\n\n**Result:** `%s`  \n**Passed:** %d  \n**Failed:** %d\n\n" % [payload.status, passed, failed]
	for result in results:
		markdown += "- %s: %s\n" % [result.status, result.label]
	var markdown_file := FileAccess.open(REPORT_DIRECTORY.path_join("godot_pipe_validation.md"), FileAccess.WRITE)
	markdown_file.store_string(markdown)
