class_name BossSpawner
extends Node2D

@export var boss_scenes: Array[PackedScene] = []
@export_range(1.0, 600.0, 1.0) var initial_spawn_delay := 18.0
@export_range(1.0, 600.0, 1.0) var delay_between_bosses := 55.0
@export_range(200.0, 3000.0, 10.0) var spawn_radius := 680.0

var _spawn_remaining := 0.0
var _next_boss_index := 0
var _first_cycle_defeated := 0
var _second_cycle := false


func _ready() -> void:
	_spawn_remaining = initial_spawn_delay
	GameManager.boss_defeated.connect(_on_boss_defeated)
	_validate_catalog()


func _physics_process(delta: float) -> void:
	if boss_scenes.is_empty() or not is_instance_valid(GameManager.player) or not GameManager.active_bosses.is_empty():
		return
	_spawn_remaining -= delta
	if _spawn_remaining <= 0.0:
		spawn_next_wave()


func spawn_next_boss() -> void:
	spawn_next_wave()


func spawn_next_wave() -> void:
	if boss_scenes.is_empty() or not GameManager.active_bosses.is_empty():
		return
	var count := 2 if _second_cycle else 1
	for slot in range(count):
		_spawn_boss_at_index(_next_boss_index, slot, count)
		_next_boss_index = (_next_boss_index + 1) % boss_scenes.size()
	_spawn_remaining = delay_between_bosses


func _spawn_boss_at_index(index: int, slot: int, count: int) -> void:
	var boss := boss_scenes[index].instantiate() as BossController
	if boss == null:
		push_error("Boss scene root must inherit BossController.")
		return
	get_parent().add_child(boss)
	var angle := randf_range(0.0, TAU) + TAU * slot / maxf(count, 1.0)
	boss.global_position = GameManager.player.global_position + Vector2.RIGHT.rotated(angle) * spawn_radius


func _on_boss_defeated(_definition: BossDefinition) -> void:
	if not _second_cycle:
		_first_cycle_defeated += 1
		if _first_cycle_defeated >= boss_scenes.size():
			_second_cycle = true
			_next_boss_index = 0
	if GameManager.active_bosses.is_empty():
		_spawn_remaining = delay_between_bosses


func _validate_catalog() -> void:
	for scene in boss_scenes:
		if scene == null:
			push_error("Boss spawner contains an empty scene entry.")
