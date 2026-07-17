class_name AirstrikeSpell
extends Spell

var _warning_positions: Array[Vector2] = []
var _blast_positions: Array[Vector2] = []
var _elapsed := 0.0
var _next_detonation := 0.0
var _detonation_index := 0
var _finished_delay := 0.0


func activate() -> void:
	super.activate()
	global_position = target_position
	var strike_count := maxi(definition.burst_count, 5)
	_warning_positions.append(Vector2.ZERO)
	for index in range(strike_count - 1):
		var angle := randf_range(0.0, TAU)
		var distance := sqrt(randf()) * 245.0
		_warning_positions.append(Vector2.RIGHT.rotated(angle) * distance)
	_warning_positions.shuffle()
	_next_detonation = definition.impact_delay
	queue_redraw()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _detonation_index < _warning_positions.size() and _elapsed >= _next_detonation:
		_detonate_next_zone()
		_next_detonation += definition.burst_interval
	if _detonation_index >= _warning_positions.size():
		_finished_delay -= delta
		if _finished_delay <= 0.0:
			finish()
	queue_redraw()


func _detonate_next_zone() -> void:
	var position := _warning_positions[_detonation_index]
	_detonation_index += 1
	_blast_positions.append(position)
	damage_circle(global_position + position, get_area_radius(), 1.0)
	VFXManager.spawn_death(get_parent(), global_position + position, definition.primary_color)
	AudioManager.play_spell_sfx(global_position + position, definition.sound_pitch_hz + randf_range(-35.0, 35.0), 0.16)
	CameraEffects.shake(4.0, 0.12)
	_finished_delay = 0.42


func _draw() -> void:
	if definition == null:
		return
	var telegraph_progress := clampf(_elapsed / maxf(definition.impact_delay, 0.01), 0.0, 1.0)
	for index in range(_detonation_index, _warning_positions.size()):
		var position := _warning_positions[index]
		var pulse := 0.38 + sin(_elapsed * 11.0 + index) * 0.16
		var warning_color := Color(definition.primary_color, pulse)
		draw_circle(position, get_area_radius(), Color(warning_color, 0.07 + telegraph_progress * 0.07))
		draw_arc(position, get_area_radius(), -PI * 0.5, -PI * 0.5 + TAU * telegraph_progress, 36, warning_color, 4.0 + telegraph_progress * 3.0, true)
		draw_line(position + Vector2(-12, 0), position + Vector2(12, 0), definition.secondary_color, 3.0, true)
		draw_line(position + Vector2(0, -12), position + Vector2(0, 12), definition.secondary_color, 3.0, true)
	for blast_index in range(_blast_positions.size()):
		var age := (_blast_positions.size() - 1 - blast_index) * definition.burst_interval
		var alpha := clampf(1.0 - age / 0.7, 0.0, 1.0)
		draw_arc(_blast_positions[blast_index], get_area_radius() * (1.0 + age), 0.0, TAU, 36, Color(definition.secondary_color, alpha), 8.0, true)
