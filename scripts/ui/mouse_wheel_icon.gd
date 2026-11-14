class_name MouseWheelIcon
extends Control

const OUTLINE := Color("d9e6ec")
const BODY := Color("0d1a23")
const WHEEL := Color("57d9f5")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(42.0, 52.0)
	queue_redraw()

func _draw() -> void:
	var width := size.x
	var height := size.y
	var center := Vector2(width * 0.5, height * 0.45)
	var radius := minf(width * 0.31, height * 0.27)
	var lower_left := Vector2(width * 0.19, height * 0.45)
	var lower_right := Vector2(width * 0.81, height * 0.45)
	var lower_y := height * 0.76

	draw_circle(center, radius, BODY)
	draw_rect(Rect2(lower_left, Vector2(lower_right.x - lower_left.x, lower_y - lower_left.y)), BODY)
	draw_arc(center, radius, PI, TAU, 24, OUTLINE, 1.8, true)
	draw_line(lower_left, Vector2(lower_left.x, lower_y), OUTLINE, 1.8, true)
	draw_line(lower_right, Vector2(lower_right.x, lower_y), OUTLINE, 1.8, true)
	draw_arc(Vector2(width * 0.5, lower_y), width * 0.31, 0.0, PI, 24, OUTLINE, 1.8, true)
	draw_line(Vector2(width * 0.5, height * 0.18), Vector2(width * 0.5, height * 0.45), OUTLINE, 1.3, true)

	var wheel := Rect2(Vector2(width * 0.43, height * 0.27), Vector2(width * 0.14, height * 0.19))
	draw_rect(wheel, WHEEL)
	draw_rect(wheel, Color("b9f5ff"), false, 1.0, true)
