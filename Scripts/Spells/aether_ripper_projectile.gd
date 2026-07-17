class_name AetherRipperProjectile
extends ProjectileSpell


func _draw() -> void:
	if definition == null:
		return
	# A compact enchanted round with a luminous core, stabilizing fins, and a hot trail.
	draw_circle(Vector2(-18, 0), 9.0, Color(definition.primary_color, 0.10))
	draw_circle(Vector2(-11, 0), 6.0, Color(definition.primary_color, 0.24))
	draw_colored_polygon(PackedVector2Array([
		Vector2(13, 0), Vector2(3, -6), Vector2(-8, -5),
		Vector2(-13, 0), Vector2(-8, 5), Vector2(3, 6),
	]), definition.primary_color.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, 0), Vector2(1, -3.5), Vector2(-9, 0), Vector2(1, 3.5),
	]), definition.secondary_color)
	draw_line(Vector2(-7, -5), Vector2(-14, -9), definition.primary_color, 2.5)
	draw_line(Vector2(-7, 5), Vector2(-14, 9), definition.primary_color, 2.5)
	draw_circle(Vector2(2, 0), 2.2, Color.WHITE)
