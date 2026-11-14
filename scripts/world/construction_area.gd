class_name ConstructionArea
extends Node3D

@export_range(1, 1024, 1) var width: int = 64
@export_range(1, 1024, 1) var depth: int = 64

func contains_cell(x: int, z: int) -> bool:
	return x >= 0 and x < width and z >= 0 and z < depth

func contains_base_cell(x: int, y: int, z: int) -> bool:
	return y == 0 and contains_cell(x, z)

func contains_volume_cell(cell: Vector3i) -> bool:
	return cell.y >= 0 and contains_cell(cell.x, cell.z)

func cell_count() -> int:
	return width * depth
