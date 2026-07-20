class_name EnemySpawner
extends Node2D

@export var enemy_scene: PackedScene
@export var enemy_definitions: Array[Resource] = []
@export_range(0.1, 30.0, 0.1) var spawn_interval := 1.15
@export_range(1, 500, 1) var maximum_enemies := 65
@export_range(0.0, 2.0, 0.01) var difficulty_growth_per_minute := 0.22
@export_range(1.0, 5.0, 0.05) var boss_spawn_interval_multiplier := 1.75
@export_range(0.1, 1.0, 0.05) var boss_enemy_cap_multiplier := 0.65
@export_range(0.0, 2.0, 0.05) var difficulty_per_boss_tier := 0.42
@export_range(0.0, 2.0, 0.05) var experience_growth_per_boss_tier := 0.55
@export_range(100.0, 3000.0, 10.0) var minimum_spawn_radius := 620.0
@export_range(100.0, 4000.0, 10.0) var maximum_spawn_radius := 840.0

var _time_until_spawn := 0.5
var _elapsed_time := 0.0
var _enemy_tier := 0


func _ready() -> void:
	GameManager.boss_registered.connect(_on_boss_registered)


func _physics_process(delta: float) -> void:
	_elapsed_time += delta
	if not is_instance_valid(GameManager.player) or enemy_scene == null or enemy_definitions.is_empty():
		return
	_time_until_spawn -= delta
	if _time_until_spawn > 0.0:
		return
	var interval := spawn_interval / _current_difficulty()
	if is_instance_valid(GameManager.current_boss):
		interval *= boss_spawn_interval_multiplier
	_time_until_spawn = maxf(interval, 0.42)
	var active_cap := roundi(maximum_enemies * boss_enemy_cap_multiplier) if is_instance_valid(GameManager.current_boss) else maximum_enemies
	if GameManager.enemies.size() >= active_cap:
		return
	spawn_enemy(_choose_definition())


func spawn_enemy(selected_definition: EnemyDefinition) -> void:
	if selected_definition == null:
		return
	var enemy := enemy_scene.instantiate()
	enemy.definition = selected_definition
	enemy.difficulty_multiplier = _current_difficulty()
	enemy.empowerment_tier = _enemy_tier
	enemy.experience_multiplier = 1.0 + _enemy_tier * experience_growth_per_boss_tier
	get_parent().add_child(enemy)
	var angle := randf_range(0.0, TAU)
	var radius := randf_range(minimum_spawn_radius, maximum_spawn_radius)
	enemy.global_position = GameManager.player.global_position + Vector2.RIGHT.rotated(angle) * radius


func spawn_ambush(center: Vector2, count := 7) -> void:
	for index in range(clampi(count, 1, 14)):
		var selected := _choose_definition()
		if selected == null:
			continue
		var enemy := enemy_scene.instantiate()
		enemy.definition = selected
		enemy.difficulty_multiplier = _current_difficulty()
		enemy.empowerment_tier = _enemy_tier
		enemy.experience_multiplier = 1.0 + _enemy_tier * experience_growth_per_boss_tier
		get_parent().add_child(enemy)
		var angle := TAU * index / maxf(count, 1.0) + randf_range(-0.16, 0.16)
		enemy.global_position = center + Vector2.RIGHT.rotated(angle) * randf_range(135.0, 215.0)


func _current_difficulty() -> float:
	return 1.0 + (_elapsed_time / 60.0) * difficulty_growth_per_minute + _enemy_tier * difficulty_per_boss_tier


func _on_boss_registered(_boss: Node2D, _definition: BossDefinition) -> void:
	_enemy_tier += 1


func _choose_definition() -> EnemyDefinition:
	var total_weight := 0.0
	for resource in enemy_definitions:
		var item := resource as EnemyDefinition
		if item == null:
			continue
		total_weight += item.spawn_weight
	if total_weight <= 0.0:
		return null
	var roll := randf() * total_weight
	for resource in enemy_definitions:
		var item := resource as EnemyDefinition
		if item == null:
			continue
		roll -= item.spawn_weight
		if roll <= 0.0:
			return item
	return enemy_definitions.back() as EnemyDefinition
