class_name BossHazard
extends Area2D

enum ShapeType { CIRCLE, LINE }

var shape_type := ShapeType.CIRCLE
var radius := 90.0
var line_length := 600.0
var line_width := 46.0
var warning_duration := 0.9
var active_duration := 0.3
var damage := 25.0
var accent_color := Color.RED

var _elapsed := 0.0
var _has_damaged: Dictionary = {}


func configure_circle(world_position: Vector2, hazard_radius: float, warning: float, active: float, amount: float, color: Color) -> void:
	global_position = world_position
	shape_type = ShapeType.CIRCLE
	radius = hazard_radius
	warning_duration = warning
	active_duration = active
	damage = amount
	accent_color = color


func configure_line(world_position: Vector2, angle: float, length: float, width: float, warning: float, active: float, amount: float, color: Color) -> void:
	global_position = world_position
	global_rotation = angle
	shape_type = ShapeType.LINE
	line_length = length
	line_width = width
	warning_duration = warning
	active_duration = active
	damage = amount
	accent_color = color


func _ready() -> void:
	add_to_group("network_hazards")
	collision_layer = 64
	collision_mask = 1
	monitoring = true
	_build_collision()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= warning_duration:
		for body in get_overlapping_bodies():
			_damage_body(body)
	queue_redraw()
	if _elapsed >= warning_duration + active_duration:
		queue_free()


func _damage_body(body: Node) -> void:
	if not body.has_method("apply_damage") or _has_damaged.has(body.get_instance_id()):
		return
	_has_damaged[body.get_instance_id()] = true
	body.apply_damage(damage)


func _build_collision() -> void:
	var collision := CollisionShape2D.new()
	if shape_type == ShapeType.CIRCLE:
		var circle := CircleShape2D.new()
		circle.radius = radius
		collision.shape = circle
	else:
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(line_length, line_width)
		collision.position.x = line_length * 0.5
		collision.shape = rectangle
	add_child(collision)


func _draw() -> void:
	var is_active := _elapsed >= warning_duration
	var pulse := 0.45 + sin(_elapsed * 16.0) * 0.18
	var color := accent_color
	color.a = 0.62 if is_active else pulse
	if shape_type == ShapeType.CIRCLE:
		draw_circle(Vector2.ZERO, radius, Color(color, 0.24 if is_active else 0.08))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, 9.0 if is_active else 4.0, true)
	else:
		draw_rect(Rect2(0.0, -line_width * 0.5, line_length, line_width), Color(color, 0.32 if is_active else 0.08), true)
		draw_line(Vector2.ZERO, Vector2(line_length, 0), color, 8.0 if is_active else 3.0, true)
