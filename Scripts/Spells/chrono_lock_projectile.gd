class_name ChronoLockProjectile
extends ProjectileSpell


func _on_area_entered(area: Area2D) -> void:
	if _ended or not area.has_method("receive_hit"):
		return
	var target_id := area.get_instance_id()
	if _hit_ids.has(target_id):
		return
	_hit_ids[target_id] = true
	damage_hurtbox(area, 0.35, Vector2.ZERO)
	var field := ChronoLockField.new()
	get_parent().add_child(field)
	field.configure(definition, caster, area.global_position, area.global_position, modifiers)
	field.bind_target(area)
	field.activate()
	CameraEffects.flash(Color("80edff"), 0.12, 0.1)
	_end_projectile(false)


func _draw() -> void:
	if definition == null:
		return
	var time := Time.get_ticks_msec() * 0.006
	draw_circle(Vector2.ZERO, 14.0, Color(0.3, 0.82, 1.0, 0.22))
	draw_arc(Vector2.ZERO, 11.0, time, time + 5.0, 24, definition.primary_color, 2.5, true)
	draw_line(Vector2.ZERO, Vector2(7, 0).rotated(time * 0.7), Color.WHITE, 2.0, true)
	draw_line(Vector2.ZERO, Vector2(5, 0).rotated(-time * 1.8), definition.secondary_color, 2.0, true)
	draw_circle(Vector2.ZERO, 2.5, Color.WHITE)
