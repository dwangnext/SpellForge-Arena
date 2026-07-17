class_name LineSpell
extends Spell

var _elapsed := 0.0
var _tick_remaining := 0.0
var _line_length := 0.0
var _line_shape := RectangleShape2D.new()
var _line_query := PhysicsShapeQueryParameters2D.new()


func activate() -> void:
	super.activate()
	_line_length = cast_origin.distance_to(target_position)
	_line_shape.size = Vector2(_line_length, definition.line_width)
	_line_query.shape = _line_shape
	_line_query.collision_mask = 16
	_line_query.collide_with_areas = true
	_line_query.collide_with_bodies = false
	_tick_remaining = 0.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_tick_remaining -= delta
	if _tick_remaining <= 0.0:
		_tick_remaining = definition.tick_interval
		_damage_line()
	queue_redraw()
	if _elapsed >= definition.duration:
		finish()


func _damage_line() -> void:
	_line_query.transform = Transform2D(direction.angle(), cast_origin + direction * _line_length * 0.5)
	for result in get_world_2d().direct_space_state.intersect_shape(_line_query, 128):
		var hurtbox := result.get("collider") as Area2D
		if hurtbox != null:
			damage_hurtbox(hurtbox, 1.0, direction)


func _draw() -> void:
	if definition == null:
		return
	var end := Vector2(_line_length, 0.0)
	if definition.visual_style == SpellDefinition.VisualStyle.LIGHTNING:
		var points := PackedVector2Array([Vector2.ZERO])
		for segment in range(1, 9):
			var progress := float(segment) / 9.0
			points.append(Vector2(_line_length * progress, randf_range(-definition.line_width, definition.line_width)))
		points.append(end)
		draw_polyline(points, definition.primary_color, definition.line_width * 0.32, true)
		draw_polyline(points, definition.secondary_color, 3.0, true)
	else:
		draw_line(Vector2.ZERO, end, Color(definition.primary_color, 0.25), definition.line_width * 1.8, true)
		draw_line(Vector2.ZERO, end, definition.primary_color, definition.line_width, true)
		draw_line(Vector2.ZERO, end, definition.secondary_color, maxf(definition.line_width * 0.22, 2.0), true)
