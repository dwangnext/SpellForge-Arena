class_name RiotShieldProjectile
extends ProjectileSpell


func _draw() -> void:
	if definition == null:
		return
	draw_circle(Vector2.ZERO, 24.0, Color(definition.primary_color, 0.16))
	draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 28, definition.primary_color.darkened(0.35), 9.0, true)
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 28, definition.secondary_color, 3.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(15, 0), Vector2(5, -11), Vector2(-9, -8),
		Vector2(-13, 0), Vector2(-9, 8), Vector2(5, 11),
	]), definition.primary_color)
	draw_line(Vector2(-6, 0), Vector2(9, 0), Color.WHITE, 4.0, true)
	draw_line(Vector2(2, -7), Vector2(2, 7), Color.WHITE, 4.0, true)
