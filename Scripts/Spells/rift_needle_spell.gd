class_name RiftNeedleSpell
extends Spell

var _elapsed := 0.0
var _line_length := 0.0
var _seam_snapped := false
var _rectangle := RectangleShape2D.new()
var _query := PhysicsShapeQueryParameters2D.new()


func activate() -> void:
	super.activate()
	_line_length = cast_origin.distance_to(target_position)
	_query.shape = _rectangle
	_query.collision_mask = 16
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	_damage_seam(0.48)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if not _seam_snapped and _elapsed >= definition.impact_delay:
		_seam_snapped = true
		_damage_seam(1.0)
		CameraEffects.shake(8.0, 0.18)
		AudioManager.play_spell_sfx(cast_origin + direction * _line_length * 0.5, definition.sound_pitch_hz * 0.55, 0.18)
	queue_redraw()
	if _elapsed >= definition.duration:
		finish()


func _damage_seam(multiplier: float) -> void:
	_rectangle.size = Vector2(maxf(_line_length, 1.0), maxf(definition.line_width * modifiers.area_multiplier, 8.0))
	_query.transform = Transform2D(direction.angle(), cast_origin + direction * _line_length * 0.5)
	var hit_ids: Dictionary = {}
	for result in get_world_2d().direct_space_state.intersect_shape(_query, 128):
		var hurtbox := result.get("collider") as Area2D
		if hurtbox == null or hit_ids.has(hurtbox.get_instance_id()):
			continue
		hit_ids[hurtbox.get_instance_id()] = true
		damage_hurtbox(hurtbox, multiplier, direction)


func _draw() -> void:
	if definition == null:
		return
	var life := clampf(_elapsed / maxf(definition.duration, 0.01), 0.0, 1.0)
	var needle_progress := clampf(_elapsed / maxf(definition.impact_delay, 0.01), 0.0, 1.0)
	var needle := Vector2(_line_length * needle_progress, 0.0)
	var seam_color := Color(definition.secondary_color, 0.95 if _seam_snapped else 0.35)
	draw_line(Vector2.ZERO, Vector2(_line_length, 0.0), Color(definition.primary_color, (1.0 - life) * 0.5), definition.line_width if _seam_snapped else 3.0, true)
	draw_line(Vector2.ZERO, Vector2(_line_length, 0.0), seam_color, 3.0 if _seam_snapped else 1.5, true)
	draw_colored_polygon(PackedVector2Array([needle + Vector2(24, 0), needle + Vector2(-12, -7), needle + Vector2(-5, 0), needle + Vector2(-12, 7)]), Color.WHITE if _seam_snapped else definition.secondary_color)
	for stitch in range(1, 9):
		var x := _line_length * stitch / 9.0
		draw_line(Vector2(x, -8), Vector2(x, 8), Color(definition.primary_color, 1.0 - life), 2.0, true)
