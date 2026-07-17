class_name PlasmaOrbSpell
extends ProjectileSpell


func _on_area_entered(area: Area2D) -> void:
	if _ended or not area.has_method("receive_hit"):
		return
	var target_id := area.get_instance_id()
	if _hit_ids.has(target_id):
		return
	_hit_ids[target_id] = true
	damage_circle(global_position, get_area_radius(), 1.0)
	damage_circle(global_position, get_area_radius() * 1.75, 0.34)
	VFXManager.spawn_death(get_parent(), global_position, definition.secondary_color)
	CameraEffects.flash(definition.primary_color, 0.12, 0.1)
	_end_projectile(false)


func _draw() -> void:
	if definition == null:
		return
	draw_circle(Vector2.ZERO, 17.0, Color(definition.primary_color, 0.3))
	draw_circle(Vector2.ZERO, 10.0, definition.secondary_color)
	for arc in range(4):
		var angle := Time.get_ticks_msec() * 0.008 + TAU * arc / 4.0
		draw_line(Vector2.RIGHT.rotated(angle) * 10.0, Vector2.RIGHT.rotated(angle + 0.35) * 23.0, definition.primary_color, 3.0, true)
