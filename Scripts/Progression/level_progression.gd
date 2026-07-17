class_name LevelProgression
extends Node

signal progress_changed(level: int, current_xp: int, required_xp: int)
signal level_gained(level: int)

@export_range(1, 1000, 1) var base_requirement := 12
@export_range(1.0, 3.0, 0.01) var growth_exponent := 1.28

var level := 1
var current_xp := 0
var _last_total_experience := 0


func _ready() -> void:
	GameManager.rewards_changed.connect(_on_rewards_changed)
	call_deferred("_emit_progress")


func required_xp() -> int:
	return maxi(roundi(base_requirement * pow(float(level), growth_exponent)), 1)


func _on_rewards_changed(total_experience: int, _coins: int) -> void:
	var gained := maxi(total_experience - _last_total_experience, 0)
	_last_total_experience = total_experience
	if gained <= 0:
		return
	current_xp += gained
	while current_xp >= required_xp():
		current_xp -= required_xp()
		level += 1
		MetaProgression.set_stat_max("highest_level", level)
		level_gained.emit(level)
	_emit_progress()


func _emit_progress() -> void:
	progress_changed.emit(level, current_xp, required_xp())
