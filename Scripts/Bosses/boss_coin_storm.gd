class_name BossCoinStorm
extends Node2D

const COIN_SCENE := preload("res://Scenes/Pickups/Coin.tscn")
const DURATION := 10.0
const SPAWN_INTERVAL := 0.16
const COINS_PER_BURST := 4
const RAIN_RADIUS := 360.0

var _remaining := DURATION
var _spawn_remaining := 0.0
var _color := Color("ffd447")


func configure(world_position: Vector2, color: Color) -> void:
	global_position = world_position
	_color = color
	queue_redraw()


func _process(delta: float) -> void:
	_remaining -= delta
	_spawn_remaining -= delta
	if _spawn_remaining <= 0.0:
		_spawn_remaining = SPAWN_INTERVAL
		for index in range(COINS_PER_BURST):
			_spawn_coin(index)
	queue_redraw()
	if _remaining <= 0.0:
		queue_free()


func _spawn_coin(index: int) -> void:
	var landing := global_position + Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * sqrt(randf()) * RAIN_RADIUS
	var coin := COIN_SCENE.instantiate() as RewardPickup
	coin.value = 1
	get_parent().add_child(coin)
	coin.global_position = landing + Vector2(randf_range(-45.0, 45.0), -randf_range(180.0, 360.0) - index * 18.0)
	coin.monitoring = false
	coin.set_physics_process(false)
	var tween := coin.create_tween()
	tween.tween_property(coin, "global_position", landing, randf_range(0.32, 0.62)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if is_instance_valid(coin):
			coin.monitoring = true
			coin.set_physics_process(true)
	)


func _draw() -> void:
	var alpha := minf(_remaining, 1.0)
	for index in range(22):
		var x := randf_range(-RAIN_RADIUS, RAIN_RADIUS)
		var y := randf_range(-280.0, 120.0)
		draw_line(Vector2(x, y), Vector2(x - 12.0, y + 34.0), Color(_color, 0.24 * alpha), 3.0, true)
	draw_arc(Vector2.ZERO, RAIN_RADIUS, 0.0, TAU, 64, Color(_color, 0.18 * alpha), 4.0, true)
