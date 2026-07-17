class_name GravityWellRound
extends ProjectileSpell

var _deployed := false
var _well_remaining := 0.0
var _pulse_remaining := 0.0
var _rotation_time := 0.0


func _physics_process(delta: float) -> void:
	_rotation_time += delta
	if not _deployed:
		var movement := direction * get_speed() * delta
		global_position += movement
		_distance_traveled += movement.length()
		global_rotation = direction.angle()
		if _distance_traveled >= get_cast_range():
			_deploy_well()
	else:
		_well_remaining -= delta
		_pulse_remaining -= delta
		if _pulse_remaining <= 0.0:
			_pulse_remaining = definition.tick_interval
			damage_circle(global_position, get_area_radius(), 0.24)
			AudioManager.play_spell_sfx(global_position, definition.sound_pitch_hz, 0.06)
		if _well_remaining <= 0.0:
			finish()
	queue_redraw()


func _on_area_entered(area: Area2D) -> void:
	if _deployed or not area.has_method("receive_hit"):
		return
	damage_hurtbox(area, 0.7, direction)
	_deploy_well()


func _deploy_well() -> void:
	if _deployed:
		return
	_deployed = true
	_well_remaining = definition.duration
	_pulse_remaining = 0.0
	hitbox.set_deferred("monitoring", false)
	VFXManager.spawn_death(get_parent(), global_position, definition.secondary_color)
	CameraEffects.shake(8.0, 0.24)


func _draw() -> void:
	if definition == null:
		return
	if not _deployed:
		draw_circle(Vector2.ZERO, 13.0, definition.primary_color)
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 20, definition.secondary_color, 4.0, true)
		return
	draw_circle(Vector2.ZERO, get_area_radius(), Color(definition.primary_color, 0.08))
	draw_circle(Vector2.ZERO, 24.0, Color("030108"))
	for arm in range(7):
		var angle := _rotation_time * 2.4 + TAU * arm / 7.0
		var inner := Vector2.RIGHT.rotated(angle) * 27.0
		var outer := Vector2.RIGHT.rotated(angle + 0.5) * get_area_radius() * 0.9
		draw_line(inner, outer, Color(definition.secondary_color, 0.72), 6.0, true)
