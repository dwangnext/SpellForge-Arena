class_name RewardPickup
extends Area2D

enum RewardType { EXPERIENCE, COIN }

@export var reward_type := RewardType.EXPERIENCE
@export var value := 1
@export_range(20.0, 1000.0, 10.0) var attraction_speed := 360.0
@export_range(20.0, 1000.0, 10.0) var attraction_radius := 180.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	rotation += delta * 2.2
	if not is_instance_valid(GameManager.player):
		return
	var offset := GameManager.player.global_position - global_position
	if offset.length() <= attraction_radius:
		global_position = global_position.move_toward(GameManager.player.global_position, attraction_speed * delta)


func _on_body_entered(body: Node) -> void:
	if body != GameManager.player:
		return
	if reward_type == RewardType.EXPERIENCE:
		GameManager.add_experience(value)
		AudioManager.play_spell_sfx(global_position, 680.0, 0.08)
	else:
		GameManager.add_coins(value)
		AudioManager.play_spell_sfx(global_position, 920.0, 0.1)
	queue_free()


func _draw() -> void:
	if reward_type == RewardType.EXPERIENCE:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -10), Vector2(8, 0), Vector2(0, 10), Vector2(-8, 0)]), Color("55d6be"))
		draw_polyline(PackedVector2Array([Vector2(0, -10), Vector2(8, 0), Vector2(0, 10), Vector2(-8, 0), Vector2(0, -10)]), Color("b5fff1"), 2.0)
	else:
		draw_circle(Vector2.ZERO, 9.0, Color("e5ae38"))
		draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 16, Color("fff0a6"), 2.0)
