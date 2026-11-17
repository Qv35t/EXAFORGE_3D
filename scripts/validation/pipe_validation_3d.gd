extends Node3D

const PIPE_STRAIGHT := preload("res://assets/models/pipes/EXAFORGE_Pipe_Straight.glb")
const PIPE_CORNER := preload("res://assets/models/pipes/EXAFORGE_Pipe_Corner_90.glb")
const PIPE_CROSS := preload("res://assets/models/pipes/EXAFORGE_Pipe_Cross.glb")
const PIPE_T := preload("res://assets/models/pipes/EXAFORGE_Pipe_T_Junction.glb")

const PORTS := {
	"straight": {"WEST": Vector3(-0.5, 0.0, 0.0), "EAST": Vector3(0.5, 0.0, 0.0)},
	"corner": {"NORTH": Vector3(0.0, 0.0, -0.5), "EAST": Vector3(0.5, 0.0, 0.0)},
	"cross": {"WEST": Vector3(-0.5, 0.0, 0.0), "EAST": Vector3(0.5, 0.0, 0.0), "NORTH": Vector3(0.0, 0.0, -0.5), "SOUTH": Vector3(0.0, 0.0, 0.5)},
	"tee": {"WEST": Vector3(-0.5, 0.0, 0.0), "EAST": Vector3(0.5, 0.0, 0.0), "NORTH": Vector3(0.0, 0.0, -0.5)},
}

var marker_materials: Dictionary[String, StandardMaterial3D] = {}


func _ready() -> void:
	marker_materials = {
		"connected": _material(Color(0.12, 0.95, 0.36, 0.95)),
		"open": _material(Color(1.0, 0.76, 0.10, 0.95)),
		"error": _material(Color(1.0, 0.18, 0.18, 0.95)),
		"cell": _material(Color(0.22, 0.68, 1.0, 0.08)),
	}
	_build_floor()
	_build_zone_a()
	_build_zone_b()
	_build_zone_c()
	_build_zone_d()
	_build_zone_e()


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _build_floor() -> void:
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(28.0, 24.0)
	floor.mesh = plane
	floor.position = Vector3(1.5, -0.13, 5.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.035, 0.05, 0.07, 1.0)
	material.metallic = 0.15
	material.roughness = 0.88
	floor.material_override = material
	add_child(floor)


func _build_zone_a() -> void:
	_label("A  Individual models: cell, pivot and open ports", Vector3(-8.0, 0.35, -4.2))
	var entries := [["straight", Vector3(-7.0, 0.0, -2.8)], ["corner", Vector3(-5.0, 0.0, -2.8)], ["tee", Vector3(-7.0, 0.0, -0.8)], ["cross", Vector3(-5.0, 0.0, -0.8)]]
	for entry in entries:
		_add_pipe(entry[0], entry[1], 0.0, true)


func _build_zone_b() -> void:
	_label("B  Linear connections", Vector3(-1.5, 0.35, -4.2))
	for offset in range(3):
		_add_pipe("straight", Vector3(-1.0 + offset, 0.0, -2.8), 0.0, false)
	_add_pipe("straight", Vector3(-1.0, 0.0, -0.8), 0.0, false)
	_add_pipe("tee", Vector3(0.0, 0.0, -0.8), 0.0, false)
	_add_pipe("straight", Vector3(1.0, 0.0, -0.8), 0.0, false)
	_add_pipe("straight", Vector3(-1.0, 0.0, 1.2), 0.0, false)
	_add_pipe("cross", Vector3(0.0, 0.0, 1.2), 0.0, false)
	_add_pipe("straight", Vector3(1.0, 0.0, 1.2), 0.0, false)


func _build_zone_c() -> void:
	_label("C  Corners: 0, 90, 180, 270 degrees", Vector3(5.0, 0.35, -4.2))
	# A one-cell square makes every quarter-turn contact a real shared cell face.
	_add_pipe("corner", Vector3(5.5, 0.0, -1.3), 0.0, false)
	_add_pipe("corner", Vector3(6.5, 0.0, -1.3), PI * 0.5, false)
	_add_pipe("corner", Vector3(6.5, 0.0, -2.3), PI, false)
	_add_pipe("corner", Vector3(5.5, 0.0, -2.3), PI * 1.5, false)


func _build_zone_d() -> void:
	_label("D  Combined 16-module network", Vector3(-7.5, 0.35, 3.4))
	var network := [
		["straight", Vector3(-7.0, 0.0, 4.5), 0.0], ["straight", Vector3(-6.0, 0.0, 4.5), 0.0],
		["tee", Vector3(-5.0, 0.0, 4.5), 0.0], ["straight", Vector3(-4.0, 0.0, 4.5), 0.0],
		["corner", Vector3(-3.0, 0.0, 4.5), PI], ["straight", Vector3(-3.0, 0.0, 5.5), PI * 0.5],
		["cross", Vector3(-3.0, 0.0, 6.5), 0.0], ["straight", Vector3(-4.0, 0.0, 6.5), 0.0],
		["tee", Vector3(-5.0, 0.0, 6.5), PI], ["straight", Vector3(-6.0, 0.0, 6.5), 0.0],
		["corner", Vector3(-7.0, 0.0, 6.5), PI * 1.5], ["straight", Vector3(-7.0, 0.0, 5.5), PI * 0.5],
		["straight", Vector3(-5.0, 0.0, 3.5), PI * 0.5], ["corner", Vector3(-5.0, 0.0, 2.5), PI * 0.5],
		["straight", Vector3(-4.0, 0.0, 2.5), 0.0], ["cross", Vector3(-3.0, 0.0, 2.5), 0.0],
	]
	for entry in network:
		_add_pipe(entry[0], entry[1], entry[2], false)


func _build_zone_e() -> void:
	_label("E  Diameter comparison: OD 0.18 / ID 0.14", Vector3(3.5, 0.35, 3.4))
	var entries := [["straight", Vector3(4.0, 0.0, 5.2)], ["corner", Vector3(6.0, 0.0, 5.2)], ["tee", Vector3(4.0, 0.0, 7.0)], ["cross", Vector3(6.0, 0.0, 7.0)]]
	for entry in entries:
		_add_pipe(entry[0], entry[1], 0.0, true)


func _add_pipe(kind: String, position: Vector3, rotation_y: float, show_open_ports: bool) -> void:
	var packed: PackedScene = {"straight": PIPE_STRAIGHT, "corner": PIPE_CORNER, "cross": PIPE_CROSS, "tee": PIPE_T}[kind]
	var pipe := packed.instantiate() as Node3D
	pipe.name = "Pipe_%s" % kind.capitalize()
	pipe.position = position
	pipe.rotation.y = rotation_y
	pipe.scale = Vector3.ONE
	add_child(pipe)
	_add_cell(position)
	for port_position in PORTS[kind].values():
		var rotated: Vector3 = (port_position as Vector3).rotated(Vector3.UP, rotation_y)
		_add_marker(position + rotated, "open" if show_open_ports else "connected")


func _add_cell(position: Vector3) -> void:
	var cell := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)
	cell.mesh = mesh
	cell.position = position
	cell.material_override = marker_materials["cell"]
	add_child(cell)


func _add_marker(position: Vector3, state: String) -> void:
	var marker := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.026
	mesh.height = 0.052
	marker.mesh = mesh
	marker.position = position
	marker.material_override = marker_materials[state]
	add_child(marker)


func _label(text_value: String, position: Vector3) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.font_size = 42
	label.outline_size = 8
	label.modulate = Color(0.78, 0.9, 1.0, 1.0)
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
