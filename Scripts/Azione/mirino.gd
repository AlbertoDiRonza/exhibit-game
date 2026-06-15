extends Control

@export var crosshair_color: Color = Color(1, 1, 1, 0.85)
@export var crosshair_size: float = 12.0
@export var crosshair_gap: float = 4.0
@export var thickness: float = 2.0

func _draw():
	var center = crosshair_size + crosshair_gap
	var total = (crosshair_size + crosshair_gap) * 2

	draw_line(Vector2(0, center), Vector2(crosshair_size, center), crosshair_color, thickness)
	draw_line(Vector2(crosshair_size + crosshair_gap * 2, center), Vector2(total, center), crosshair_color, thickness)
	draw_line(Vector2(center, 0), Vector2(center, crosshair_size), crosshair_color, thickness)
	draw_line(Vector2(center, crosshair_size + crosshair_gap * 2), Vector2(center, total), crosshair_color, thickness)
