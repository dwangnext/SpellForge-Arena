class_name StasisMeteorSpell
extends Spell

var _elapsed := 0.0
var _pulse_index := 0
var _next_pulse := 0.0
var _finished_delay := 0.0


func activate() -> void:
	super.activate()
	global_position = target_position
	_next_pulse = definition.impact_delay
	queue_redraw()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _pulse_index < 3 and _elapsed >= _next_pulse:
		var multiplier: float = [1.0, 0.48, 0.32][_pulse_index]
		damage_circle(global_position, get_area_radius() * (1.0 + _pulse_index * 0.16), multiplier)
		VFXManager.spawn_death(get_parent(), global_position, definition.primary_color.lightened(_pulse_index * 0.12))
		AudioManager.play_spell_sfx(global_position, definition.sound_pitch_hz * (0.62 + _pulse_index * 0.16), 0.22)
		_pulse_index += 1
		_next_pulse += 0.36
		_finished_delay = 0.28
	if _pulse_index >= 3:
		_finished_delay -= delta
		if _finished_delay <= 0.0:
			finish()
	queue_redraw()


func _draw() -> void:
	if definition == null:
		return
	if _pulse_index == 0:
		var warning_alpha := 0.25 + sin(_elapsed * 15.0) * 0.12
		draw_circle(Vector2.ZERO, get_area_radius(), Color(definition.primary_color, warning_alpha * 0.25))
		draw_arc(Vector2.ZERO, get_area_radius(), 0.0, TAU, 56, Color(definition.primary_color, warning_alpha), 7.0, true)
		var descent := clampf(_elapsed / maxf(definition.impact_delay, 0.01), 0.0, 1.0)
		draw_circle(Vector2(0, lerpf(-definition.speed * definition.impact_delay, 0.0, descent)), 28.0, definition.secondary_color)
	else:
		for ring in range(_pulse_index):
			var radius := get_area_radius() * (0.35 + ring * 0.28 + fmod(_elapsed * 0.8, 0.24))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(definition.primary_color, 0.7 - ring * 0.15), 6.0, true)
