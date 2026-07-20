class_name SpawnerUnitProjectile
extends Area2D

var direction := Vector2.RIGHT
var damage := 10.0
var accent_color := Color("75e6a4")
var speed := 620.0
var lifetime := 1.2
var tier := 0


func configure(position: Vector2, travel_direction: Vector2, amount: float, color: Color, ship_tier := 0) -> void:
	global_position = position
	direction = travel_direction.normalized()
	damage = amount
	accent_color = color
	tier = ship_tier
	speed += tier * 45.0


func _ready() -> void:
	add_to_group("network_projectiles")
	collision_layer = 8
	collision_mask = 16
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0 + tier * 0.35
	collision.shape = shape
	add_child(collision)
	area_entered.connect(_on_area_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not area.has_method("receive_hit"):
		return
	var hit_position := area.global_position
	var payload := DamagePayload.new(damage, self, hit_position, direction, 25.0)
	area.receive_hit(payload)
	queue_free()


func _draw() -> void:
	draw_line(Vector2(-13, 0), Vector2(-3, 0), Color(accent_color, 0.35), 4.0, true)
	draw_circle(Vector2.ZERO, 5.0 + tier * 0.35, accent_color)
