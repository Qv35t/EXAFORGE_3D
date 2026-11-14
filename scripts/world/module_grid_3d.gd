class_name ModuleGrid3D
extends RefCounted

var construction_area: ConstructionArea
var occupied_cells: Dictionary[Vector3i, String] = {}

func _init(area: ConstructionArea) -> void:
	construction_area = area

static func cell_to_world(cell: Vector3i) -> Vector3:
	return Vector3(cell.x + 0.5, cell.y + 0.5, cell.z + 0.5)

static func world_to_cell(world_position: Vector3) -> Vector3i:
	return Vector3i(floori(world_position.x), floori(world_position.y), floori(world_position.z))

func is_valid_cell(cell: Vector3i) -> bool:
	return construction_area != null and construction_area.contains_volume_cell(cell)

func can_occupy(cell: Vector3i) -> bool:
	return is_valid_cell(cell) and not occupied_cells.has(cell)

func occupy(cell: Vector3i, module_type: String) -> bool:
	if not can_occupy(cell):
		return false
	occupied_cells[cell] = module_type
	return true

func release(cell: Vector3i) -> bool:
	if not occupied_cells.has(cell):
		return false
	occupied_cells.erase(cell)
	return true

func is_occupied(cell: Vector3i) -> bool:
	return occupied_cells.has(cell)

func occupant_type(cell: Vector3i) -> String:
	return occupied_cells.get(cell, "")

func occupancy_count() -> int:
	return occupied_cells.size()
