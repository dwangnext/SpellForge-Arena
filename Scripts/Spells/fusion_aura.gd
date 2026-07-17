class_name FusionAura
extends Node2D

var primary_color := Color.WHITE
var secondary_color := Color.WHITE
var _time := 0.0


func configure(primary: Color, secondary: Color) -> void:
	primary_color = primary
	secondary_color = secondary
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	rotation = _time * 2.4
	queue_redraw()


func _draw() -> void:
	var pulse := 18.0 + sin(_time * 8.0) * 3.0
	draw_arc(Vector2.ZERO, pulse, 0.0, 2.1, 12, Color(primary_color, 0.65), 2.5, true)
	draw_arc(Vector2.ZERO, pulse, PI, PI + 2.1, 12, Color(secondary_color, 0.65), 2.5, true)
	draw_circle(Vector2.RIGHT.rotated(_time * 3.0) * pulse, 2.8, secondary_color)
	draw_circle(Vector2.RIGHT.rotated(_time * 3.0 + PI) * pulse, 2.8, primary_color)
