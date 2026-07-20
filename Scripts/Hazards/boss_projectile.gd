class_name BossProjectile
extends Area2D

var direction := Vector2.RIGHT
var speed := 320.0
var damage := 18.0
var lifetime := 4.0
var radius := 11.0
var accent_color := Color.RED
var visual_style := "standard"


func configure(world_position: Vector2, travel_direction: Vector2, travel_speed: float, amount: float, projectile_radius: float, color: Color, duration: float = 4.0) -> void:
	global_position = world_position
	direction = travel_direction.normalized()
	speed = travel_speed
	damage = amount
	radius = projectile_radius
	accent_color = color
	lifetime = duration


func _ready() -> void:
	add_to_group("network_projectiles")
	collision_layer = 64
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	collision.shape = circle
	add_child(collision)
	queue_redraw()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if visual_style in ["odyssey_beam", "aries_beam", "aries_dart"]:
		rotation = direction.angle()
	else:
		rotation += delta * 5.0
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.has_method("apply_damage"):
		body.apply_damage(damage)
		queue_free()


func _draw() -> void:
	if visual_style in ["odyssey_beam", "aries_beam"]:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(2.4, 0.72))
		draw_circle(Vector2.ZERO, radius, accent_color)
		draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 18, Color.WHITE, 2.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif visual_style == "aries_dart":
		draw_colored_polygon(PackedVector2Array([Vector2(8, 0), Vector2(-5, -3), Vector2(-5, 3)]), accent_color)
	else:
		draw_circle(Vector2.ZERO, radius, accent_color)
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 18, Color(accent_color, 0.45), 3.0, true)
