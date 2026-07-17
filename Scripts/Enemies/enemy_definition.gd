class_name EnemyDefinition
extends Resource

@export var display_name := "Enemy"
@export var color := Color("d95863")
@export_range(1.0, 10000.0, 1.0) var maximum_health := 40.0
@export_range(10.0, 1000.0, 5.0) var movement_speed := 120.0
@export_range(0.0, 1000.0, 1.0) var contact_damage := 10.0
@export_range(0.0, 500.0, 1.0) var defense := 0.0
@export_range(0.5, 3.0, 0.05) var visual_scale := 1.0
@export_range(0, 1000, 1) var experience_value := 5
@export_range(0.0, 1.0, 0.01) var coin_drop_chance := 0.2
@export_range(0, 1000, 1) var coin_value := 1
@export_range(0.01, 100.0, 0.1) var spawn_weight := 1.0
