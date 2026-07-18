class_name RiftAnchorSpell
extends Spell

var _elapsed := 0.0
var _anchor_position := Vector2.ZERO
var _target: Node2D


func activate() -> void:
	super.activate()
	_target = _find_target_near_cursor()
	_anchor_position = _target.global_position if is_instance_valid(_target) else target_position
	if is_instance_valid(_target):
		var hurtbox := _target.get_node_or_null("HurtboxComponent") as Area2D
		if hurtbox != null:
			damage_hurtbox(hurtbox, 1.0, Vector2.ZERO)
	else:
		damage_circle(_anchor_position, get_area_radius(), 0.72)
	CameraEffects.shake(7.0, 0.18)
	CameraEffects.flash(definition.secondary_color, 0.1, 0.1)
	queue_redraw()


func _find_target_near_cursor() -> Node2D:
	var nearest: Node2D
	var nearest_distance := pow(maxf(get_area_radius() * 1.8, 150.0), 2.0)
	var candidates: Array[Node2D] = GameManager.enemies.duplicate()
	if is_instance_valid(GameManager.current_boss) and not candidates.has(GameManager.current_boss):
		candidates.append(GameManager.current_boss)
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		var distance := target_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(_target):
		_anchor_position = _target.global_position
	queue_redraw()
	if _elapsed >= definition.duration:
		finish()


func _draw() -> void:
	if definition == null:
		return
	var fade := 1.0 - clampf(_elapsed / maxf(definition.duration, 0.01), 0.0, 1.0)
	var anchor := to_local(_anchor_position)
	draw_line(Vector2.ZERO, anchor, Color(definition.primary_color, 0.26 * fade), 13.0, true)
	for link in range(9):
		var point := Vector2.ZERO.lerp(anchor, float(link + 1) / 10.0)
		draw_circle(point, 4.0, Color(definition.secondary_color, fade))
	draw_circle(anchor, 34.0, Color(definition.primary_color, 0.14 * fade))
	for claw in range(4):
		var angle := _elapsed * 4.0 + claw * TAU / 4.0
		var outside := anchor + Vector2.RIGHT.rotated(angle) * 38.0
		var inside := anchor + Vector2.RIGHT.rotated(angle) * 18.0
		draw_line(outside, inside, Color(definition.secondary_color, fade), 8.0, true)
