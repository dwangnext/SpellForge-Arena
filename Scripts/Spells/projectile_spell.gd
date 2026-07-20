class_name ProjectileSpell
extends Spell

@onready var hitbox: Area2D = $Hitbox

var _distance_traveled := 0.0
var _hit_ids: Dictionary = {}
var _remaining_pierces := 0
var _remaining_bounces := 0
var _ended := false
var _homing_target: Node2D
var _homing_refresh_remaining := 0.0

const HOMING_REFRESH_INTERVAL := 0.12
const MAX_BOUNCE_DISTANCE_SQUARED := 320.0 * 320.0


func supports_projectile_modifiers() -> bool:
	return true


func activate() -> void:
	super.activate()
	_remaining_pierces = definition.pierce_count + modifiers.pierce_bonus
	_remaining_bounces = modifiers.bounce_count
	hitbox.area_entered.connect(_on_area_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if definition.homing or modifiers.homing_enabled:
		_update_homing(delta)
	var movement := direction * get_speed() * delta
	global_position += movement
	_distance_traveled += movement.length()
	global_rotation = direction.angle()
	queue_redraw()
	if _distance_traveled >= get_cast_range():
		_end_projectile()


func _update_homing(delta: float) -> void:
	_homing_refresh_remaining -= delta
	if not is_instance_valid(_homing_target) or _homing_target.is_queued_for_deletion() or _homing_refresh_remaining <= 0.0:
		_homing_refresh_remaining = HOMING_REFRESH_INTERVAL
		_homing_target = _find_nearest_enemy(false)
	if is_instance_valid(_homing_target):
		var desired := global_position.direction_to(_homing_target.global_position)
		direction = direction.lerp(desired, clampf((definition.homing_strength + modifiers.homing_strength_bonus) * delta, 0.0, 1.0)).normalized()


func _on_area_entered(area: Area2D) -> void:
	if _ended or not area.has_method("receive_hit"):
		return
	var target_id := area.get_instance_id()
	if _hit_ids.has(target_id):
		return
	_hit_ids[target_id] = true
	if definition.area_radius > 0.0:
		damage_circle(global_position, get_area_radius())
		if not _try_bounce():
			_end_projectile(false)
	else:
		damage_hurtbox(area, 1.0, direction)
		if not _try_bounce():
			if _remaining_pierces > 0:
				_remaining_pierces -= 1
			else:
				_end_projectile(false)


func _end_projectile(apply_area: bool = true) -> void:
	if _ended:
		return
	_ended = true
	if apply_area and definition.area_radius > 0.0:
		damage_circle(global_position, get_area_radius())
	finish()


func _try_bounce() -> bool:
	if _remaining_bounces <= 0:
		return false
	var nearest := _find_nearest_enemy(true, MAX_BOUNCE_DISTANCE_SQUARED)
	if nearest == null:
		return false
	_remaining_bounces -= 1
	_homing_target = nearest
	direction = global_position.direction_to(nearest.global_position)
	_distance_traveled = 0.0
	return true


func _find_nearest_enemy(exclude_hit_targets: bool, maximum_distance_squared: float = INF) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := INF
	var candidates: Array[Node2D] = GameManager.enemies.duplicate()
	for boss in GameManager.active_bosses:
		if is_instance_valid(boss) and not candidates.has(boss):
			candidates.append(boss)
	for candidate in candidates:
		var enemy := candidate as Node2D
		if enemy == null or enemy.is_queued_for_deletion():
			continue
		if exclude_hit_targets:
			var hurtbox := enemy.get_node_or_null("HurtboxComponent")
			if hurtbox == null or _hit_ids.has(hurtbox.get_instance_id()):
				continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance and distance <= maximum_distance_squared:
			nearest_distance = distance
			nearest = enemy
	return nearest


func _draw() -> void:
	if definition == null:
		return
	match definition.visual_style:
		SpellDefinition.VisualStyle.FIRE:
			draw_circle(Vector2.ZERO, 14.0, definition.primary_color)
			draw_circle(Vector2(-12, 0), 8.0, Color(definition.primary_color, 0.35))
		SpellDefinition.VisualStyle.ICE:
			draw_colored_polygon(PackedVector2Array([Vector2(18, 0), Vector2(-9, -8), Vector2(-4, 0), Vector2(-9, 8)]), definition.primary_color)
		SpellDefinition.VisualStyle.ARCANE:
			draw_circle(Vector2.ZERO, 9.0, definition.primary_color)
			draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 16, definition.secondary_color, 3.0)
		SpellDefinition.VisualStyle.RAPID:
			draw_line(Vector2(-24, 0), Vector2(-6, 0), Color(definition.primary_color, 0.3), 7.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(13, 0), Vector2(3, -5), Vector2(-9, -4), Vector2(-9, 4), Vector2(3, 5)]), definition.primary_color)
			draw_line(Vector2(-5, -2), Vector2(7, -2), definition.secondary_color, 2.0, true)
		_:
			draw_circle(Vector2.ZERO, 10.0, definition.primary_color)
