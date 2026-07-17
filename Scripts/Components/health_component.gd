class_name HealthComponent
extends Node

signal health_changed(current_health: float, maximum_health: float)
signal damaged(amount: float)
signal healed(amount: float)
signal died

@export_range(1.0, 10000.0, 1.0) var maximum_health := 100.0
@export var start_at_full_health := true

var current_health := 0.0
var is_dead := false


func _ready() -> void:
	current_health = maximum_health if start_at_full_health else clampf(current_health, 0.0, maximum_health)
	health_changed.emit(current_health, maximum_health)


func take_damage(amount: float) -> float:
	if is_dead or amount <= 0.0:
		return 0.0
	var previous_health := current_health
	current_health = maxf(current_health - amount, 0.0)
	var applied_damage := previous_health - current_health
	damaged.emit(applied_damage)
	health_changed.emit(current_health, maximum_health)
	if current_health <= 0.0:
		is_dead = true
		died.emit()
	return applied_damage


func heal(amount: float) -> float:
	if is_dead or amount <= 0.0:
		return 0.0
	var previous_health := current_health
	current_health = minf(current_health + amount, maximum_health)
	var applied_healing := current_health - previous_health
	if applied_healing > 0.0:
		healed.emit(applied_healing)
		health_changed.emit(current_health, maximum_health)
	return applied_healing


func restore_to_full() -> void:
	is_dead = false
	current_health = maximum_health
	health_changed.emit(current_health, maximum_health)
