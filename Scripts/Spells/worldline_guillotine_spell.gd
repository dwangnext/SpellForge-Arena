class_name WorldlineGuillotineSpell
extends Spell

var _elapsed := 0.0
var _struck := false
var _line_length := 0.0
var _shape := RectangleShape2D.new()
var _query := PhysicsShapeQueryParameters2D.new()


func activate() -> void:
	super.activate()
	_line_length = get_cast_range()
	_shape.size = Vector2(_line_length, definition.line_width)
	_query.shape = _shape
	_query.collision_mask = 16
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	queue_redraw()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if not _struck and _elapsed >= definition.impact_delay:
		_strike_once()
	queue_redraw()
	if _elapsed >= definition.duration:
		finish()


func _strike_once() -> void:
	_struck = true
	_query.transform = Transform2D(direction.angle(), cast_origin + direction * _line_length * 0.5)
	for result in get_world_2d().direct_space_state.intersect_shape(_query, 128):
		var hurtbox := result.get("collider") as Area2D
		if hurtbox != null:
			damage_hurtbox(hurtbox, 1.0, direction)
	VFXManager.spawn_death(get_parent(), cast_origin + direction * _line_length * 0.5, definition.primary_color)
	CameraEffects.shake(15.0, 0.28)
	CameraEffects.flash(Color("f6c7ff"), 0.26, 0.12)
	AudioManager.play_spell_sfx(cast_origin, 68.0, 0.62)


func _draw() -> void:
	if definition == null:
		return
	var end := Vector2(_line_length, 0.0)
	if not _struck:
		var warning := clampf(_elapsed / maxf(definition.impact_delay, 0.01), 0.0, 1.0)
		draw_line(Vector2.ZERO, end, Color(definition.primary_color, 0.10 + warning * 0.22), definition.line_width, true)
		draw_line(Vector2.ZERO, end, Color(definition.secondary_color, 0.45 + warning * 0.4), 2.0 + warning * 4.0, true)
		for index in range(7):
			var center := end * (float(index) / 6.0)
			draw_line(center + Vector2(0, -definition.line_width * 0.65), center + Vector2(0, definition.line_width * 0.65), Color(definition.primary_color, warning), 3.0, true)
	else:
		var fade := 1.0 - clampf((_elapsed - definition.impact_delay) / maxf(definition.duration - definition.impact_delay, 0.01), 0.0, 1.0)
		draw_line(Vector2.ZERO, end, Color(definition.primary_color, 0.45 * fade), definition.line_width * 2.4, true)
		draw_line(Vector2.ZERO, end, Color.WHITE, fade, true)
		draw_line(Vector2.ZERO, end, Color(definition.secondary_color, fade), 8.0, true)
