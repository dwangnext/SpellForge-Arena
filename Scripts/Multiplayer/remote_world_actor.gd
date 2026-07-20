class_name RemoteWorldActor
extends Node2D

var network_id := ""
var is_boss := false
var _target_position := Vector2.ZERO
var _accent_color := Color("e34c67")
var _visual_radius := 20.0
var _health_ratio := 1.0
var _shield_ratio := 0.0
var _is_ally := false
var _ally_kind := ""
var _label := ""
var _space_tier := 0
var _received_state := false
var _hurtbox: Area2D


func _ready() -> void:
	_hurtbox = Area2D.new()
	_hurtbox.name = "HurtboxComponent"
	_hurtbox.collision_layer = 16
	_hurtbox.collision_mask = 8
	_hurtbox.monitoring = false
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = _visual_radius
	collision.shape = circle
	_hurtbox.add_child(collision)
	add_child(_hurtbox)
	GameManager.register_enemy(self)


func _exit_tree() -> void:
	GameManager.unregister_enemy(self)


func apply_snapshot(data: Dictionary) -> void:
	_target_position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	rotation = float(data.get("rotation", 0.0))
	_accent_color = Color(String(data.get("color", "e34c67")))
	_visual_radius = float(data.get("radius", 20.0))
	_health_ratio = clampf(float(data.get("health", 1.0)), 0.0, 1.0)
	_shield_ratio = clampf(float(data.get("shield", 0.0)), 0.0, 1.0)
	is_boss = bool(data.get("boss", false))
	_is_ally = bool(data.get("ally", false))
	if _is_ally:
		GameManager.unregister_enemy(self)
		if is_instance_valid(_hurtbox):
			_hurtbox.collision_layer = 0
	_ally_kind = String(data.get("ally_kind", ""))
	_label = String(data.get("label", ""))
	_space_tier = int(data.get("space_tier", 0))
	if not _received_state:
		global_position = _target_position
		_received_state = true
	if is_instance_valid(_hurtbox):
		var collision := _hurtbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision != null and collision.shape is CircleShape2D:
			(collision.shape as CircleShape2D).radius = _visual_radius
	queue_redraw()


func _process(delta: float) -> void:
	global_position = global_position.lerp(_target_position, 1.0 - exp(-16.0 * delta))
	queue_redraw()


func receive_hit(payload: DamagePayload) -> void:
	VFXManager.spawn_hit(get_parent(), payload.hit_position, _accent_color)


func _draw() -> void:
	var radius := _visual_radius
	if _is_ally:
		if _ally_kind == "structure":
			draw_rect(Rect2(-radius, -radius * 0.72, radius * 2.0, radius * 1.44), _accent_color.darkened(0.25), true)
			draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 30, _accent_color, 4.0, true)
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(radius + 5, 0), Vector2(-radius, -radius * 0.7), Vector2(-radius * 0.45, 0), Vector2(-radius, radius * 0.7)]), _accent_color)
		var ally_bar_width := radius * 2.2
		draw_rect(Rect2(-ally_bar_width * 0.5, -radius - 14.0, ally_bar_width, 5.0), Color(0.04, 0.04, 0.08, 0.9), true)
		draw_rect(Rect2(-ally_bar_width * 0.5, -radius - 14.0, ally_bar_width * _health_ratio, 5.0), Color("76f29e"), true)
		draw_string(ThemeDB.fallback_font, Vector2(-radius * 1.5, radius + 18), _label, HORIZONTAL_ALIGNMENT_CENTER, radius * 3.0, 11, Color.WHITE)
		return
	draw_circle(Vector2.ZERO, radius + 6.0, Color(_accent_color, 0.16))
	draw_circle(Vector2.ZERO, radius, _accent_color.darkened(0.28))
	draw_circle(Vector2(0, -radius * 0.12), radius * 0.82, _accent_color)
	if is_boss:
		draw_arc(Vector2.ZERO, radius + 10.0, 0.0, TAU, 42, Color("ffd447"), 5.0, true)
	else:
		draw_circle(Vector2(-radius * 0.28, -radius * 0.25), 3.0, Color.WHITE)
		draw_circle(Vector2(radius * 0.28, -radius * 0.25), 3.0, Color.WHITE)
		if _shield_ratio > 0.0:
			draw_arc(Vector2.ZERO, radius + 7.0, -PI * 0.5, -PI * 0.5 + TAU * _shield_ratio, 30, Color("ffd447").lerp(Color("b45cff"), 1.0 - _shield_ratio), 4.0, true)
	var bar_width := radius * 2.2
	draw_rect(Rect2(-bar_width * 0.5, -radius - 14.0, bar_width, 5.0), Color(0.04, 0.04, 0.08, 0.9), true)
	draw_rect(Rect2(-bar_width * 0.5, -radius - 14.0, bar_width * _health_ratio, 5.0), Color("ffcb58" if is_boss else "66ef9a"), true)
