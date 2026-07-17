class_name BossSpawner
extends Node2D

@export var boss_scenes: Array[PackedScene] = []
@export_range(1.0, 600.0, 1.0) var initial_spawn_delay := 18.0
@export_range(1.0, 600.0, 1.0) var delay_between_bosses := 55.0
@export_range(200.0, 3000.0, 10.0) var spawn_radius := 680.0

var _spawn_remaining := 0.0
var _next_boss_index := 0


func _ready() -> void:
	_spawn_remaining = initial_spawn_delay
	GameManager.boss_defeated.connect(_on_boss_defeated)
	_validate_catalog()


func _physics_process(delta: float) -> void:
	if boss_scenes.is_empty() or not is_instance_valid(GameManager.player) or is_instance_valid(GameManager.current_boss):
		return
	_spawn_remaining -= delta
	if _spawn_remaining <= 0.0:
		spawn_next_boss()


func spawn_next_boss() -> void:
	if boss_scenes.is_empty() or is_instance_valid(GameManager.current_boss):
		return
	var boss := boss_scenes[_next_boss_index].instantiate() as BossController
	if boss == null:
		push_error("Boss scene root must inherit BossController.")
		return
	_next_boss_index = (_next_boss_index + 1) % boss_scenes.size()
	get_parent().add_child(boss)
	var angle := randf_range(0.0, TAU)
	boss.global_position = GameManager.player.global_position + Vector2.RIGHT.rotated(angle) * spawn_radius
	_spawn_remaining = delay_between_bosses


func _on_boss_defeated(_definition: BossDefinition) -> void:
	_spawn_remaining = delay_between_bosses


func _validate_catalog() -> void:
	for scene in boss_scenes:
		if scene == null:
			push_error("Boss spawner contains an empty scene entry.")
