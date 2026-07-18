class_name RiftStepSpell
extends Spell

var _elapsed := 0.0
var _slash_length := 0.0
var _shape := RectangleShape2D.new()
var _query := PhysicsShapeQueryParameters2D.new()


func activate() -> void:
	super.activate()
	_slash_length = cast_origin.distance_to(target_position)
	_shape.size = Vector2(maxf(_slash_length, 1.0), definition.line_width)
	_query.shape = _shape
	_query.transform = Transform2D(direction.angle(), cast_origin + direction * _slash_length * 0.5)
	_query.collision_mask = 16
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	for result in get_world_2d().direct_space_state.intersect_shape(_query, 128):
		var hurtbox := result.get("collider") as Area2D
		if hurtbox != null:
			damage_hurtbox(hurtbox, 1.0, direction)
	if is_instance_valid(caster):
		caster.global_position = target_position
		if caster.has_method("grant_temporary_speed"):
			caster.grant_temporary_speed(1.18, 0.75)
	CameraEffects.shake(7.0, 0.18)
	CameraEffects.flash(Color("ef68ff"), 0.14, 0.12)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= definition.duration:
		finish()


func _draw() -> void:
	if definition == null:
		return
	var fade := 1.0 - clampf(_elapsed / maxf(definition.duration, 0.01), 0.0, 1.0)
	var end := Vector2(_slash_length, 0.0)
	draw_line(Vector2.ZERO, end, Color(0.55, 0.05, 1.0, 0.18 * fade), definition.line_width * 2.2, true)
	draw_line(Vector2.ZERO, end, Color(definition.primary_color, 0.72 * fade), definition.line_width, true)
	draw_line(Vector2.ZERO, end, Color(definition.secondary_color, fade), 5.0, true)
	for index in range(6):
		var progress := float(index) / 5.0
		var center := end * progress
		draw_arc(center, 18.0 + index * 3.0, -1.2, 1.2, 12, Color(definition.secondary_color, fade * (1.0 - progress * 0.5)), 3.0, true)
