class_name DragonFlameSpell
extends Spell

const CONE_HALF_ANGLE := deg_to_rad(31.0)

var _elapsed := 0.0
var _tick_remaining := 0.0
var _query_shape := CircleShape2D.new()
var _query := PhysicsShapeQueryParameters2D.new()


func activate() -> void:
	super.activate()
	_query_shape.radius = get_cast_range()
	_query.shape = _query_shape
	_query.collision_mask = 16
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	if is_instance_valid(caster) and caster.has_method("grant_temporary_speed"):
		caster.grant_temporary_speed(1.38, definition.duration + 0.8)
	CameraEffects.flash(Color("ff793d"), 0.09, 0.08)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_tick_remaining -= delta
	if is_instance_valid(caster):
		global_position = caster.global_position
		direction = Vector2.RIGHT.rotated(caster.global_rotation)
		global_rotation = direction.angle()
	if _tick_remaining <= 0.0:
		_tick_remaining += definition.tick_interval
		_damage_cone()
	queue_redraw()
	if _elapsed >= definition.duration:
		finish()


func _damage_cone() -> void:
	_query.transform = Transform2D(0.0, global_position)
	for result in get_world_2d().direct_space_state.intersect_shape(_query, 128):
		var hurtbox := result.get("collider") as Area2D
		if hurtbox == null:
			continue
		var offset := hurtbox.global_position - global_position
		if offset.length_squared() <= 1.0 or absf(direction.angle_to(offset.normalized())) <= CONE_HALF_ANGLE:
			damage_hurtbox(hurtbox, 1.0, Vector2.ZERO)


func _draw() -> void:
	if definition == null:
		return
	var life := clampf(_elapsed / maxf(definition.duration, 0.01), 0.0, 1.0)
	var flicker := 0.86 + sin(_elapsed * 48.0) * 0.12
	var length := get_cast_range() * flicker
	var outer := PackedVector2Array([Vector2(8, 0)])
	var inner := PackedVector2Array([Vector2(12, 0)])
	for index in range(13):
		var amount := float(index) / 12.0
		var angle := lerpf(-CONE_HALF_ANGLE, CONE_HALF_ANGLE, amount)
		outer.append(Vector2.RIGHT.rotated(angle) * length * (0.86 + sin(index * 2.7 + _elapsed * 35.0) * 0.08))
		inner.append(Vector2.RIGHT.rotated(angle * 0.72) * length * 0.72)
	draw_colored_polygon(outer, Color(1.0, 0.15, 0.025, 0.38 * (1.0 - life * 0.35)))
	draw_colored_polygon(inner, Color(1.0, 0.78, 0.12, 0.72))
	for index in range(5):
		var progress := fmod(_elapsed * (2.2 + index * 0.18) + index * 0.19, 1.0)
		var flame_position := Vector2(get_cast_range() * progress, sin(_elapsed * 24.0 + index * 1.7) * progress * 65.0)
		draw_circle(flame_position, lerpf(14.0, 4.0, progress), Color("fff2a3" if index % 2 == 0 else "ff4d27"))
