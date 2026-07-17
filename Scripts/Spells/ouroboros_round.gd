class_name OuroborosRound
extends ProjectileSpell

var _returning := false
var _travel := 0.0
var _spin := 0.0


func _physics_process(delta: float) -> void:
	_spin += delta
	if _returning:
		if not is_instance_valid(caster):
			finish()
			return
		direction = global_position.direction_to(caster.global_position)
		if global_position.distance_squared_to(caster.global_position) <= 34.0 * 34.0:
			finish()
			return
	var movement := direction * get_speed() * delta
	global_position += movement
	_travel += movement.length()
	global_rotation = direction.angle()
	if not _returning and _travel >= get_cast_range():
		_returning = true
		_travel = 0.0
		_hit_ids.clear()
		AudioManager.play_spell_sfx(global_position, definition.sound_pitch_hz * 1.25, 0.12)
	queue_redraw()


func _on_area_entered(area: Area2D) -> void:
	if not area.has_method("receive_hit") or _hit_ids.has(area.get_instance_id()):
		return
	_hit_ids[area.get_instance_id()] = true
	damage_hurtbox(area, 1.0 if not _returning else 1.35, direction)


func _draw() -> void:
	if definition == null:
		return
	draw_arc(Vector2.ZERO, 17.0, _spin * 7.0, _spin * 7.0 + PI * 1.65, 18, definition.primary_color, 8.0, true)
	draw_circle(Vector2.RIGHT.rotated(_spin * 7.0) * 17.0, 5.0, definition.secondary_color)
	draw_line(Vector2(-23, 0), Vector2(-8, 0), Color(definition.primary_color, 0.35), 5.0, true)
