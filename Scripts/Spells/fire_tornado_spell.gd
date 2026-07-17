class_name FireTornadoSpell
extends ZoneSpell


func _draw() -> void:
	if definition == null:
		return
	var radius := get_area_radius()
	var fill := definition.primary_color
	fill.a = 0.16
	draw_circle(Vector2.ZERO, radius, fill)
	for spiral in range(4):
		var start := _elapsed * (5.0 + spiral * 0.25) + spiral * TAU / 4.0
		var points := PackedVector2Array()
		for step in range(18):
			var progress := float(step) / 17.0
			points.append(Vector2.RIGHT.rotated(start + progress * 4.8) * radius * progress)
		draw_polyline(points, definition.primary_color.lerp(definition.secondary_color, spiral / 4.0), 6.0, true)
	draw_circle(Vector2.ZERO, 18.0, definition.secondary_color)
