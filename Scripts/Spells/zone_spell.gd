class_name ZoneSpell
extends Spell

var _elapsed := 0.0
var _tick_remaining := 0.0


func activate() -> void:
	super.activate()
	global_position = target_position if get_speed() <= 0.0 else cast_origin
	_tick_remaining = 0.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if get_speed() > 0.0:
		global_position += direction * get_speed() * delta
	_tick_remaining -= delta
	if _tick_remaining <= 0.0:
		_tick_remaining = definition.tick_interval
		damage_circle(global_position, get_area_radius())
	queue_redraw()
	if _elapsed >= definition.duration:
		finish()


func _draw() -> void:
	if definition == null:
		return
	var pulse := 0.92 + sin(_elapsed * 8.0) * 0.08
	var radius := get_area_radius() * pulse
	var fill := definition.primary_color
	fill.a = 0.2
	if definition.visual_style == SpellDefinition.VisualStyle.WIND:
		for ring in range(3):
			var ring_radius := radius * (0.38 + ring * 0.25)
			draw_arc(Vector2.ZERO, ring_radius, _elapsed * 5.0 + ring, _elapsed * 5.0 + ring + 4.6, 24, definition.primary_color, 5.0, true)
	else:
		draw_circle(Vector2.ZERO, radius, fill)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, definition.primary_color, 4.0, true)
		for bubble in range(7):
			var angle := bubble * TAU / 7.0 + _elapsed * (0.7 + bubble * 0.04)
			draw_circle(Vector2.RIGHT.rotated(angle) * radius * 0.62, 5.0, definition.secondary_color)
