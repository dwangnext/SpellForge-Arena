class_name RemotePlayerAvatar
extends Node2D

var peer_id := 0
var display_name := "Teammate"
var _target_position := Vector2.ZERO
var _target_rotation := 0.0
var _network_velocity := Vector2.ZERO
var _weapon_id := "wand"
var _animation_time := 0.0
var _received_state := false


func apply_network_state(position: Vector2, facing: float, velocity: Vector2, weapon_id: String) -> void:
	_target_position = position
	_target_rotation = facing
	_network_velocity = velocity
	_weapon_id = weapon_id
	if not _received_state:
		global_position = position
		global_rotation = facing
		_received_state = true
	visible = true
	queue_redraw()


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
	draw_circle(Vector2.ZERO, 21.0, Color(0.25, 0.95, 0.86, 0.18))
	draw_circle(Vector2.ZERO, 18.0, Color("35cdbb"))
	draw_colored_polygon(PackedVector2Array([Vector2(-18, 18), Vector2(14, 18), Vector2(-4, -30)]), Color("176f82"))
	draw_circle(Vector2(2, -11), 9.0, Color("f2c9a0"))
	if _weapon_id == "revolver":
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
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
