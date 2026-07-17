class_name OrbitalPrismSpell
extends Spell

const BEAM_COUNT := 4
const BEAM_DURATION := 2.0
const BEAM_LENGTH := 430.0
const BEAM_DAMAGE_MULTIPLIER := 0.12

var _elapsed := 0.0
var _impacted := false
var _beam_remaining := BEAM_DURATION
var _beam_angle := 0.0
var _tick_remaining := 0.0
var _beam_shape := RectangleShape2D.new()
var _beam_query := PhysicsShapeQueryParameters2D.new()


func activate() -> void:
	super.activate()
	global_position = target_position
	_beam_shape.size = Vector2(BEAM_LENGTH, definition.line_width)
	_beam_query.shape = _beam_shape
	_beam_query.collision_mask = 16
	_beam_query.collide_with_areas = true
	_beam_query.collide_with_bodies = false
	queue_redraw()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if not _impacted and _elapsed >= definition.impact_delay:
		_impacted = true
		damage_circle(global_position, get_area_radius())
		CameraEffects.shake(14.0, 0.38)
		CameraEffects.flash(definition.primary_color, 0.3, 0.22)
		AudioManager.play_spell_sfx(global_position, 105.0, 0.55)
	if _impacted:
		_beam_remaining -= delta
		_beam_angle += delta * 2.8
		_tick_remaining -= delta
		if _tick_remaining <= 0.0:
			_tick_remaining = definition.tick_interval
			_damage_rotating_beams()
	queue_redraw()
	if _impacted and _beam_remaining <= 0.0:
		finish()


func _damage_rotating_beams() -> void:
	for beam_index in range(BEAM_COUNT):
		var angle := _beam_angle + TAU * beam_index / BEAM_COUNT
		var direction_vector := Vector2.RIGHT.rotated(angle)
		_beam_query.transform = Transform2D(angle, global_position + direction_vector * BEAM_LENGTH * 0.5)
		for result in get_world_2d().direct_space_state.intersect_shape(_beam_query, 128):
			var hurtbox := result.get("collider") as Area2D
			if hurtbox != null:
				damage_hurtbox(hurtbox, BEAM_DAMAGE_MULTIPLIER, direction_vector)


func _draw() -> void:
	if definition == null:
		return
	if not _impacted:
		var warning_alpha := 0.22 + sin(_elapsed * 16.0) * 0.1
		draw_circle(Vector2.ZERO, get_area_radius(), Color(definition.primary_color, warning_alpha * 0.35))
		draw_arc(Vector2.ZERO, get_area_radius(), 0.0, TAU, 48, Color(definition.secondary_color, warning_alpha + 0.25), 6.0, true)
		var descent := clampf(_elapsed / maxf(definition.impact_delay, 0.01), 0.0, 1.0)
		draw_circle(Vector2(0, lerpf(-520.0, 0.0, descent)), 25.0 + descent * 14.0, definition.primary_color)
	else:
		var fade := clampf(_beam_remaining / 0.25, 0.0, 1.0)
		draw_circle(Vector2.ZERO, 38.0, Color(definition.secondary_color, 0.75 * fade))
		for beam_index in range(BEAM_COUNT):
			var angle := _beam_angle + TAU * beam_index / BEAM_COUNT
			var endpoint := Vector2.RIGHT.rotated(angle) * BEAM_LENGTH
			draw_line(Vector2.ZERO, endpoint, Color(definition.primary_color, 0.28 * fade), definition.line_width * 1.8, true)
			draw_line(Vector2.ZERO, endpoint, Color(definition.primary_color, fade), definition.line_width, true)
			draw_line(Vector2.ZERO, endpoint, Color(definition.secondary_color, fade), 4.0, true)
