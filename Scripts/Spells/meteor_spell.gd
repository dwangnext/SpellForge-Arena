class_name MeteorSpell
extends Spell

var _elapsed := 0.0
var _impacted := false
var _aftermath_remaining := 0.28


func activate() -> void:
	super.activate()
	global_position = target_position
	queue_redraw()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if not _impacted and _elapsed >= definition.impact_delay:
		_impacted = true
		damage_circle(global_position, get_area_radius())
		AudioManager.play_spell_sfx(global_position, definition.sound_pitch_hz * 0.5, 0.32)
	if _impacted:
		_aftermath_remaining -= delta
	queue_redraw()
	if _impacted and _aftermath_remaining <= 0.0:
		finish()


func _draw() -> void:
	if definition == null:
		return
	if not _impacted:
		var warning := definition.primary_color
		warning.a = 0.4 + sin(_elapsed * 14.0) * 0.18
		draw_circle(Vector2.ZERO, get_area_radius(), Color(warning, 0.12))
		draw_arc(Vector2.ZERO, get_area_radius(), 0.0, TAU, 48, warning, 6.0, true)
		var descent := clampf(_elapsed / maxf(definition.impact_delay, 0.01), 0.0, 1.0)
		var descent_height := get_speed() * definition.impact_delay
		draw_circle(Vector2(0, lerpf(-descent_height, 0.0, descent)), 20.0 + descent * 10.0, definition.secondary_color)
	else:
		var progress := 1.0 - _aftermath_remaining / 0.28
		var blast := definition.primary_color
		blast.a = 1.0 - progress
		draw_circle(Vector2.ZERO, get_area_radius() * progress, Color(blast, blast.a * 0.22))
		draw_arc(Vector2.ZERO, get_area_radius() * progress, 0.0, TAU, 48, blast, 9.0, true)
