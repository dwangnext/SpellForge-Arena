class_name ChainFrostSpell
extends Spell

@export_range(1, 20, 1) var maximum_targets := 7
@export_range(20.0, 1000.0, 10.0) var jump_range := 280.0

var _elapsed := 0.0
var _chain_points := PackedVector2Array()


func activate() -> void:
	super.activate()
	_build_chain()
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= definition.duration:
		finish()


func _build_chain() -> void:
	_chain_points.append(Vector2.ZERO)
	var remaining: Array[Node2D] = []
	for enemy in GameManager.enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			remaining.append(enemy)
	var search_position := target_position
	for index in range(maximum_targets):
		var next := _nearest_enemy(remaining, search_position, get_cast_range() if index == 0 else jump_range)
		if next == null:
			break
		remaining.erase(next)
		var hurtbox := next.get_node_or_null("HurtboxComponent") as Area2D
		if hurtbox != null:
			damage_hurtbox(hurtbox, 1.0, next.global_position - search_position)
		_chain_points.append(to_local(next.global_position))
		search_position = next.global_position


func _nearest_enemy(candidates: Array[Node2D], origin: Vector2, maximum_distance: float) -> Node2D:
	var nearest: Node2D
	var nearest_distance := maximum_distance * maximum_distance
	for enemy in candidates:
		var distance := origin.distance_squared_to(enemy.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest


func _draw() -> void:
	if _chain_points.size() < 2:
		return
	var fade := 1.0 - clampf(_elapsed / definition.duration, 0.0, 1.0)
	var glow := definition.primary_color
	glow.a = fade * 0.45
	var core := definition.secondary_color
	core.a = fade
	draw_polyline(_chain_points, glow, 14.0, true)
	draw_polyline(_chain_points, core, 4.0, true)
	for point in _chain_points:
		draw_circle(point, 7.0, core)
