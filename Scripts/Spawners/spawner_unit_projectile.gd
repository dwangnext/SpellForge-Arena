class_name SpawnerUnitProjectile
extends Area2D

var direction := Vector2.RIGHT
var damage := 10.0
var accent_color := Color("75e6a4")
var speed := 620.0
var lifetime := 1.2
var tier := 0
var shot_style := "standard"


func configure(position: Vector2, travel_direction: Vector2, amount: float, color: Color, ship_tier := 0, style := "standard") -> void:
	global_position = position
	direction = travel_direction.normalized()
	damage = amount
	accent_color = color
	tier = ship_tier
	shot_style = style
	speed += tier * 45.0
	if shot_style in ["odyssey_beam", "aries_beam"]:
		speed = 760.0
		lifetime = 1.55
	elif shot_style == "aries_dart":
		speed = 690.0
		lifetime = 0.8


func _ready() -> void:
	add_to_group("network_projectiles")
	collision_layer = 8
	collision_mask = 16
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0 if shot_style in ["odyssey_beam", "aries_beam"] else (3.0 if shot_style == "aries_dart" else 5.0 + tier * 0.35)
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
	if shot_style in ["odyssey_beam", "aries_beam"]:
		var beam_color := Color("c9fbff") if shot_style == "odyssey_beam" else Color("ffd36b")
		draw_line(Vector2(-30, 0), Vector2(-10, 0), Color(beam_color, 0.3), 8.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(2.4, 0.72))
		draw_circle(Vector2.ZERO, 8.0, beam_color)
		draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 20, Color.WHITE, 2.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif shot_style == "aries_dart":
		draw_colored_polygon(PackedVector2Array([Vector2(8, 0), Vector2(-5, -3), Vector2(-5, 3)]), Color("ffd36b"))
	else:
		draw_line(Vector2(-13, 0), Vector2(-3, 0), Color(accent_color, 0.35), 4.0, true)
		draw_circle(Vector2.ZERO, 5.0 + tier * 0.35, accent_color)
