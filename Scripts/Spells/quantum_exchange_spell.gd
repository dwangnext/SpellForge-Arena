class_name QuantumExchangeSpell
extends Spell

var _elapsed := 0.0
var _origin := Vector2.ZERO
var _destination := Vector2.ZERO
var _target_actor: Node2D


func activate() -> void:
	super.activate()
	_origin = cast_origin
	_target_actor = _find_exchange_target()
	if not is_instance_valid(_target_actor):
		_destination = target_position
		if is_instance_valid(caster):
			caster.global_position = _destination
		damage_circle(_destination, get_area_radius(), 0.7)
	else:
		_destination = _target_actor.global_position
		var is_boss_target := _target_actor == GameManager.current_boss or bool(_target_actor.get("is_boss"))
		if is_instance_valid(caster):
			caster.global_position = _destination - direction * 62.0 if is_boss_target else _destination
		if not is_boss_target:
			_target_actor.global_position = _origin
		var hurtbox := _target_actor.get_node_or_null("HurtboxComponent") as Area2D
		if hurtbox != null:
			damage_hurtbox(hurtbox, 1.0, Vector2.ZERO)
		damage_circle(_destination, get_area_radius(), 0.55)
	CameraEffects.shake(10.0, 0.24)
	CameraEffects.flash(Color("6fffe9"), 0.18, 0.14)
	queue_redraw()


func _find_exchange_target() -> Node2D:
	var nearest: Node2D
	var nearest_distance := get_area_radius() * get_area_radius() * 4.0
	var candidates: Array[Node2D] = GameManager.enemies.duplicate()
	if is_instance_valid(GameManager.current_boss):
		candidates.append(GameManager.current_boss)
	for candidate in candidates:
		if not is_instance_valid(candidate):
			continue
		var distance := target_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _physics_process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= definition.duration:
		finish()


func _draw() -> void:
	if definition == null:
		return
	var fade := 1.0 - clampf(_elapsed / maxf(definition.duration, 0.01), 0.0, 1.0)
	var local_destination := to_local(_destination)
	draw_line(Vector2.ZERO, local_destination, Color(definition.primary_color, 0.45 * fade), 18.0, true)
	draw_line(Vector2.ZERO, local_destination, Color(definition.secondary_color, fade), 3.0, true)
	for endpoint in [Vector2.ZERO, local_destination]:
		draw_circle(endpoint, get_area_radius() * 0.42, Color(definition.primary_color, 0.12 * fade))
		draw_arc(endpoint, get_area_radius() * 0.42, _elapsed * 8.0, _elapsed * 8.0 + 5.0, 32, Color(definition.secondary_color, fade), 6.0, true)
		for index in range(4):
			var angle := _elapsed * 6.0 + TAU * index / 4.0
			draw_colored_polygon(PackedVector2Array([endpoint + Vector2.RIGHT.rotated(angle) * 22.0, endpoint + Vector2.RIGHT.rotated(angle + 0.22) * 38.0, endpoint + Vector2.RIGHT.rotated(angle - 0.22) * 38.0]), Color(definition.primary_color, fade))
