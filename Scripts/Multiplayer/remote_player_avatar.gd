class_name RemotePlayerAvatar
extends CharacterBody2D

var peer_id := 0
var display_name := "Teammate"
var _target_position := Vector2.ZERO
var _target_rotation := 0.0
var _network_velocity := Vector2.ZERO
var _weapon_id := "wand"
var _animation_time := 0.0
var _received_state := false
var _health := 100.0
var _maximum_health := 100.0
var _defeated := false
var _dropped_relics := 0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 18.0
	capsule.height = 44.0
	collision.shape = capsule
	add_child(collision)


func apply_network_state(position: Vector2, facing: float, network_velocity: Vector2, weapon_id: String, maximum_health: float = 100.0) -> void:
	_target_position = position
	_target_rotation = facing
	_network_velocity = network_velocity
	_weapon_id = weapon_id
	_maximum_health = maxf(maximum_health, 1.0)
	_health = minf(_health, _maximum_health)
	if not _received_state:
		global_position = position
		global_rotation = facing
		_received_state = true
	visible = true
	queue_redraw()


func apply_damage(amount: float) -> float:
	if _defeated or amount <= 0.0:
		return 0.0
	var previous := _health
	_health = maxf(_health - amount, 0.0)
	if _health <= 0.0:
		_defeated = true
		NetworkManager.notify_remote_player_downed(peer_id, global_position)
	queue_redraw()
	return previous - _health


func apply_network_health(current: float, maximum: float) -> void:
	_maximum_health = maxf(maximum, 1.0)
	_health = clampf(current, 0.0, _maximum_health)
	_defeated = _health <= 0.0
	visible = true
	queue_redraw()


func revive(health_ratio := 0.5) -> void:
	_defeated = false
	_health = maxf(_maximum_health * clampf(health_ratio, 0.1, 1.0), 1.0)
	visible = true
	queue_redraw()


func set_dropped_relics(count: int) -> void:
	_dropped_relics = maxi(count, 0)
	queue_redraw()


func is_combat_active() -> bool:
	return _received_state and not _defeated


func get_health_snapshot() -> Dictionary:
	return {"current": _health, "maximum": _maximum_health}


func _process(delta: float) -> void:
	_animation_time += delta
	if not _received_state:
		visible = false
		return
	global_position = global_position.lerp(_target_position, 1.0 - exp(-14.0 * delta))
	global_rotation = lerp_angle(global_rotation, _target_rotation, 1.0 - exp(-18.0 * delta))
	queue_redraw()


func _draw() -> void:
	var moving := clampf(_network_velocity.length() / 330.0, 0.0, 1.0)
	var bob := sin(_animation_time * (6.0 + moving * 5.0)) * (1.2 + moving * 2.0)
	draw_set_transform(Vector2(0, bob), 0.0, Vector2.ONE)
	if _defeated:
		draw_circle(Vector2.ZERO, 30.0, Color(1.0, 0.34, 0.42, 0.18))
		draw_arc(Vector2.ZERO, 27.0, 0.0, TAU, 28, Color("ff5d72"), 4.0, true)
	draw_circle(Vector2.ZERO, 21.0, Color(0.25, 0.95, 0.86, 0.18))
	draw_circle(Vector2.ZERO, 18.0, Color("35cdbb"))
	draw_colored_polygon(PackedVector2Array([Vector2(-18, 18), Vector2(14, 18), Vector2(-4, -30)]), Color("176f82"))
	draw_circle(Vector2(2, -11), 9.0, Color("f2c9a0"))
	if _weapon_id == "spawner":
		draw_rect(Rect2(8, -9, 33, 18), Color("2b8f74"), true)
		draw_rect(Rect2(15, -15, 10, 8), Color("8fffe5"), true)
		draw_line(Vector2(38, -2), Vector2(50, -2), Color("d9fff6"), 5.0, true)
	elif _weapon_id == "revolver":
		draw_rect(Rect2(8, -6, 31, 12), Color("d8b35f"), true)
		draw_rect(Rect2(34, -3, 17, 6), Color("f4df9a"), true)
	elif _weapon_id == "gauntlet":
		draw_colored_polygon(PackedVector2Array([Vector2(6, -11), Vector2(28, -16), Vector2(43, -7), Vector2(43, 7), Vector2(28, 16), Vector2(6, 11)]), Color("7c35a8"))
		draw_arc(Vector2(29, 0), 11.0, -2.5, 2.5, 18, Color("ff8cff"), 4.0, true)
		draw_circle(Vector2(39, 0), 5.5, Color("fff0ff"))
	else:
		draw_line(Vector2(8, 0), Vector2(32, 0), Color("d9b56d"), 5.0, true)
		draw_circle(Vector2(34, 0), 7.0, Color("70e1f5"))
	draw_set_transform(Vector2.ZERO, -global_rotation, Vector2.ONE)
	draw_string(ThemeDB.fallback_font, Vector2(-42, -42), display_name, HORIZONTAL_ALIGNMENT_CENTER, 84.0, 14, Color("8fffee"))
	if _defeated:
		draw_string(ThemeDB.fallback_font, Vector2(-56, 46), "DOWNED — PRESS E", HORIZONTAL_ALIGNMENT_CENTER, 112.0, 13, Color("ffd447"))
		for index in range(mini(_dropped_relics, 7)):
			var relic_position := Vector2((index - (mini(_dropped_relics, 7) - 1) * 0.5) * 12.0, 61.0)
			draw_colored_polygon(PackedVector2Array([relic_position + Vector2(0, -5), relic_position + Vector2(5, 0), relic_position + Vector2(0, 5), relic_position + Vector2(-5, 0)]), Color("ffd447"))
	var health_ratio := clampf(_health / maxf(_maximum_health, 1.0), 0.0, 1.0)
	draw_rect(Rect2(-34, -35, 68, 5), Color(0.04, 0.04, 0.08, 0.9), true)
	draw_rect(Rect2(-34, -35, 68 * health_ratio, 5), Color("66ef9a"), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
