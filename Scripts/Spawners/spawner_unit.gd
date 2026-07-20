class_name SpawnerUnit
extends CharacterBody2D

var display_name := "Bat Guard"
var maximum_health := 15.0
var current_health := 15.0
var damage := 10.0
var ranged := false
var accent_color := Color("75e6a4")
var is_ship := false
var ship_tier := 0
var ship_variant := ""
var _attack_remaining := 0.0
var _animation_time := 0.0
var _destroyed := false
var _lifetime := 55.0


func configure(title: String, position: Vector2, health: float, attack_damage: float, uses_range: bool, color: Color, ship := false, tier := 0, variant := "") -> void:
	display_name = title
	global_position = position
	maximum_health = health
	current_health = health
	damage = attack_damage
	ranged = uses_range
	accent_color = color
	is_ship = ship
	ship_tier = tier
	ship_variant = variant.to_lower()


func _ready() -> void:
	add_to_group("allied_targets")
	add_to_group("network_allies")
	add_to_group("spawner_units")
	collision_layer = 1
	collision_mask = 4
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0 + ship_tier * 1.5
	collision.shape = shape
	add_child(collision)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _destroyed or not NetworkManager.is_world_authority():
		return
	_animation_time += delta
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	_attack_remaining = maxf(_attack_remaining - delta, 0.0)
	var target := _nearest_enemy()
	if not is_instance_valid(target):
		velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		return
	var desired_range := 245.0 if ranged else 34.0
	var offset := target.global_position - global_position
	if offset.length() > desired_range:
		velocity = velocity.move_toward(offset.normalized() * (205.0 + ship_tier * 12.0), 820.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 1050.0 * delta)
		if _attack_remaining <= 0.0:
			_attack_remaining = maxf(1.05 - ship_tier * 0.06, 0.48) if ranged else 0.72
			_attack(target)
	move_and_slide()
	if velocity.length_squared() > 1.0:
		rotation = velocity.angle()
	queue_redraw()


func _attack(target: Node2D) -> void:
	if ranged:
		var attack_direction := global_position.direction_to(target.global_position)
		if is_ship and ship_variant == "odyssey":
			_spawn_projectile(attack_direction, 20.0, "odyssey_beam")
		elif is_ship and ship_variant == "aries":
			_spawn_projectile(attack_direction, 10.0, "aries_beam")
			for dart_index in range(5):
				_spawn_projectile(Vector2.RIGHT.rotated(TAU * dart_index / 5.0), 3.0, "aries_dart")
		else:
			_spawn_projectile(attack_direction, damage, "standard")
	else:
		_deal_damage(target, damage)


func _spawn_projectile(travel_direction: Vector2, amount: float, shot_style: String) -> void:
	var projectile := SpawnerUnitProjectile.new()
	projectile.configure(global_position, travel_direction, amount, accent_color, ship_tier, shot_style)
	get_parent().add_child(projectile)


func _deal_damage(target: Node2D, amount: float) -> void:
	if not target.has_method("receive_hit"):
		return
	var direction := global_position.direction_to(target.global_position)
	target.receive_hit(DamagePayload.new(amount, self, target.global_position, direction, 35.0))


func apply_damage(amount: float) -> float:
	if _destroyed or amount <= 0.0:
		return 0.0
	var applied := minf(amount, current_health)
	current_health -= applied
	queue_redraw()
	if current_health <= 0.0:
		_destroyed = true
		VFXManager.spawn_death(get_parent(), global_position, accent_color)
		queue_free()
	return applied


func get_health_ratio() -> float:
	return current_health / maxf(maximum_health, 1.0)


func get_network_actor_data() -> Dictionary:
	return {
		"ally": true, "ally_kind": "ship" if is_ship else "unit", "label": display_name,
		"color": accent_color.to_html(false), "radius": 16.0 + ship_tier * 1.5,
		"health": get_health_ratio(), "space_tier": ship_tier, "ship_variant": ship_variant,
	}


func _nearest_enemy() -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	var candidates: Array[Node2D] = GameManager.enemies.duplicate()
	for boss in GameManager.active_bosses:
		if is_instance_valid(boss) and not candidates.has(boss):
			candidates.append(boss)
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	return nearest


func _draw() -> void:
	var radius := 12.0 + ship_tier * 1.4
	if is_ship:
		_draw_ship(radius)
	else:
		draw_circle(Vector2.ZERO, radius, accent_color)
		if ranged:
			draw_line(Vector2(4, 0), Vector2(radius + 13, 0), Color("e8f6ff"), 4.0, true)
		else:
			draw_line(Vector2(4, -2), Vector2(radius + 10, -9), Color("d9b56d"), 5.0, true)
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	draw_rect(Rect2(-18, -26, 36, 4), Color("11131e"), true)
	draw_rect(Rect2(-18, -26, 36 * get_health_ratio(), 4), Color("76f29e"), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ship(radius: float) -> void:
	var glow := Color("9ffcff")
	if ship_variant == "odyssey":
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.5, 0.72))
		draw_circle(Vector2.ZERO, radius, accent_color.darkened(0.08))
		draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 28, glow, 2.5, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([Vector2(8, -radius), Vector2(-radius, -radius * 1.05), Vector2(-radius * 0.45, -4), Vector2(8, -5)]), accent_color.lightened(0.12))
		draw_colored_polygon(PackedVector2Array([Vector2(8, radius), Vector2(-radius, radius * 1.05), Vector2(-radius * 0.45, 4), Vector2(8, 5)]), accent_color.lightened(0.12))
		draw_circle(Vector2(radius * 0.58, 0), 5.5, Color.WHITE)
		return
	if ship_variant == "aries":
		draw_colored_polygon(PackedVector2Array([Vector2(radius + 14, 0), Vector2(3, -radius), Vector2(-radius, -radius * 0.9), Vector2(-radius * 0.55, 0), Vector2(-radius, radius * 0.9), Vector2(3, radius)]), accent_color)
		draw_colored_polygon(PackedVector2Array([Vector2(radius + 6, 0), Vector2(-5, -7), Vector2(-2, 0), Vector2(-5, 7)]), glow)
		for dart_index in range(5):
			var direction := Vector2.RIGHT.rotated(TAU * dart_index / 5.0)
			draw_circle(direction * (radius + 4.0), 3.0, Color("ffd36b"))
		return
	# Each common tier adds a new readable hull component instead of only
	# scaling the same triangle.
	draw_colored_polygon(PackedVector2Array([Vector2(radius + 8, 0), Vector2(-radius, -radius * 0.7), Vector2(-radius * 0.5, 0), Vector2(-radius, radius * 0.7)]), accent_color)
	draw_circle(Vector2(-radius * 0.35, 0), 4.0 + ship_tier * 0.5, glow)
	if ship_tier >= 1:
		draw_line(Vector2(-2, -radius * 0.35), Vector2(-radius * 0.8, -radius), accent_color.lightened(0.24), 4.0, true)
		draw_line(Vector2(-2, radius * 0.35), Vector2(-radius * 0.8, radius), accent_color.lightened(0.24), 4.0, true)
	if ship_tier >= 2:
		draw_colored_polygon(PackedVector2Array([Vector2(4, -4), Vector2(-radius * 0.5, -radius * 1.15), Vector2(-radius, -radius * 0.75)]), accent_color.darkened(0.15))
		draw_colored_polygon(PackedVector2Array([Vector2(4, 4), Vector2(-radius * 0.5, radius * 1.15), Vector2(-radius, radius * 0.75)]), accent_color.darkened(0.15))
	if ship_tier >= 3:
		draw_arc(Vector2(-radius * 0.15, 0), radius * 0.72, -1.0, 1.0, 14, glow, 2.5, true)
	if ship_tier >= 4:
		draw_circle(Vector2(radius * 0.45, -radius * 0.38), 4.0, Color("ffd36b"))
		draw_circle(Vector2(radius * 0.45, radius * 0.38), 4.0, Color("ffd36b"))
