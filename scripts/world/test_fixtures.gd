class_name TestFixtures
extends Node3D

const BELT_CELL := Vector3i(20, 0, 20)
const PIPE_CELL := Vector3i(22, 0, 20)

var grid: ModuleGrid3D

func _ready() -> void:
	var area: ConstructionArea = get_node_or_null("../ConstructionArea") as ConstructionArea
	grid = ModuleGrid3D.new(area)
	grid.occupy(BELT_CELL, "belt")
	grid.occupy(PIPE_CELL, "pipe")
