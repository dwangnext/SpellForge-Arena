class_name BossRewardPickup
extends Area2D

var definition: BossDefinition
var _animation_time := 0.0


func configure(boss_definition: BossDefinition) -> void:
	definition = boss_definition


func _ready() -> void:
	collision_layer = 32
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	collision.shape = circle
	add_child(collision)
	queue_redraw()


func _process(delta: float) -> void:
	_animation_time += delta
	rotation = sin(_animation_time * 2.0) * 0.12
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body != GameManager.player or definition == null:
		return
	GameManager.add_experience(definition.reward_experience)
	GameManager.add_coins(definition.reward_coins)
	GameManager.add_boss_reward(definition.reward_id, definition.reward_name)
	AudioManager.play_spell_sfx(global_position, 1040.0, 0.5)
	queue_free()


func _draw() -> void:
	if definition == null:
		return
	var pulse := 1.0 + sin(_animation_time * 4.0) * 0.12
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * pulse)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -24), Vector2(21, -8), Vector2(14, 20), Vector2(-14, 20), Vector2(-21, -8)]), definition.reward_color)
	draw_arc(Vector2.ZERO, 29.0, 0.0, TAU, 28, definition.reward_color.lightened(0.35), 4.0, true)
	draw_circle(Vector2.ZERO, 8.0, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
