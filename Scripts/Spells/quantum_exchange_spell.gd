class_name QuantumExchangeSpell
extends Spell

var _elapsed := 0.0
var _origin := Vector2.ZERO
var _destination := Vector2.ZERO
var _target_actor: Node2D
var _successful_exchange := false


func activate() -> void:
	super.activate()
	_origin = cast_origin
	_target_actor = _find_exchange_target()
	if not is_instance_valid(_target_actor):
		_destination = target_position
		damage_circle(_destination, get_area_radius(), 0.78)
	else:
		_destination = _target_actor.global_position
		var hurtbox := _target_actor.get_node_or_null("HurtboxComponent") as Area2D
		if hurtbox != null:
			_successful_exchange = damage_hurtbox(hurtbox, 1.0, Vector2.ZERO)
		if _successful_exchange and is_instance_valid(caster):
			var health := caster.get_node_or_null("HealthComponent") as HealthComponent
			if health != null:
				health.heal(definition.damage * modifiers.damage_multiplier * 0.18)
		damage_circle(_destination, get_area_radius(), 0.42)
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
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
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
	if _successful_exchange:
		draw_string(ThemeDB.fallback_font, local_destination + Vector2(-38, -54), "LIFE SIPHON", HORIZONTAL_ALIGNMENT_CENTER, 76.0, 13, Color(definition.secondary_color, fade))
