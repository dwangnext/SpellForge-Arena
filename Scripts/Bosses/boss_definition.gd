class_name BossDefinition
extends Resource

enum VisualStyle { COLOSSUS, WARDEN, ARCHITECT }

@export_category("Identity")
@export var id := "boss"
@export var display_name := "Boss"
@export var subtitle := ""
@export var visual_style := VisualStyle.COLOSSUS
@export var primary_color := Color("ff573d")
@export var secondary_color := Color.WHITE

@export_category("Statistics")
@export_range(1.0, 100000.0, 10.0) var maximum_health := 1200.0
@export_range(0.0, 1000.0, 5.0) var movement_speed := 80.0
@export_range(0.0, 1000.0, 1.0) var contact_damage := 25.0
@export_range(0.0, 1000.0, 1.0) var defense := 20.0
@export_range(0.2, 20.0, 0.1) var attack_interval := 2.6
@export var phase_thresholds := PackedFloat32Array([0.66, 0.33])
@export_range(0.05, 1.0, 0.05) var status_duration_multiplier := 0.3

@export_category("Reward")
@export var reward_id := "boss_reward"
@export var reward_name := "Boss Relic"
@export var reward_color := Color("ffd65a")
@export_range(0, 100000, 1) var reward_experience := 80
@export_range(0, 100000, 1) var reward_coins := 25


func get_phase_for_ratio(health_ratio: float) -> int:
	var phase := 1
	for threshold in phase_thresholds:
		if health_ratio <= threshold:
			phase += 1
	return phase


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.strip_edges().is_empty(): errors.append("Boss ID is required.")
	if display_name.strip_edges().is_empty(): errors.append("Display name is required.")
	if reward_id.strip_edges().is_empty(): errors.append("Reward ID is required.")
	if maximum_health <= 0.0: errors.append("Maximum health must be positive.")
	return errors
