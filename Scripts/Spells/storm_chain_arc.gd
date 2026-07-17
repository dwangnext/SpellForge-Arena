class_name StormChainArc
extends Node2D

var _points := PackedVector2Array()
var _color := Color("73c8ff")
var _remaining := 0.2


func configure(world_points: PackedVector2Array, color: Color) -> void:
	if world_points.is_empty():
		queue_free()
		return
	global_position = world_points[0]
	_color = color
	for point in world_points:
		_points.append(point - world_points[0])
	queue_redraw()


func _process(delta: float) -> void:
	_remaining -= delta
	modulate.a = clampf(_remaining / 0.2, 0.0, 1.0)
	if _remaining <= 0.0:
		queue_free()


func _draw() -> void:
	for index in range(_points.size() - 1):
		var start := _points[index]
		var finish := _points[index + 1]
		var bolt := PackedVector2Array([start])
		var direction := finish - start
		var normal := direction.normalized().orthogonal()
		for step in range(1, 5):
			var amount := float(step) / 5.0
			bolt.append(start.lerp(finish, amount) + normal * sin(float(step) * 8.7 + finish.x) * 7.0)
		bolt.append(finish)
		draw_polyline(bolt, Color(_color, 0.28), 8.0, true)
		draw_polyline(bolt, _color, 2.5, true)
