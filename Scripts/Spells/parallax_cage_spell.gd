class_name ParallaxCageSpell
extends Spell

var _elapsed := 0.0
var _triggered := false


func activate() -> void:
	super.activate()
	global_position = target_position
	CameraEffects.flash(definition.primary_color, 0.08, 0.08)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if not _triggered and _elapsed >= definition.impact_delay:
		_triggered = true
		damage_circle(global_position, get_area_radius(), 1.0)
		VFXManager.spawn_death(get_parent(), global_position, definition.secondary_color)
		AudioManager.play_spell_sfx(global_position, definition.sound_pitch_hz * 0.62, 0.22)
		CameraEffects.shake(11.0, 0.26)
	queue_redraw()
	if _elapsed >= definition.duration:
		finish()


func _draw() -> void:
	if definition == null:
		return
	var radius := get_area_radius()
	var telegraph := clampf(_elapsed / maxf(definition.impact_delay, 0.01), 0.0, 1.0)
	var fade := 1.0 - clampf((_elapsed - definition.impact_delay) / maxf(definition.duration - definition.impact_delay, 0.01), 0.0, 1.0) if _triggered else 1.0
	draw_circle(Vector2.ZERO, radius, Color(definition.primary_color, (0.05 + telegraph * 0.08) * fade))
	for wall in range(4):
		var angle := wall * TAU / 4.0 + PI * 0.25
		var tangent := Vector2.RIGHT.rotated(angle + PI * 0.5)
		var center := Vector2.RIGHT.rotated(angle) * radius * (1.35 - telegraph * 0.35)
		var half_width := radius * 0.54
		draw_line(center - tangent * half_width, center + tangent * half_width, Color(definition.secondary_color, fade), 10.0 if _triggered else 4.0, true)
		draw_line(center, center * 0.55, Color(definition.primary_color, 0.5 * fade), 3.0, true)
	if _triggered:
		draw_arc(Vector2.ZERO, radius * (0.7 + fade * 0.3), 0.0, TAU, 40, Color.WHITE, 7.0 * fade, true)
