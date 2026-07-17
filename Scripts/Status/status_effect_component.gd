class_name StatusEffectComponent
extends Node

signal stun_changed(is_stunned: bool)

var movement_multiplier := 1.0
var _freeze_remaining := 0.0
var _stun_remaining := 0.0
var _burn_remaining := 0.0
var _burn_damage := 0.0
var _poison_remaining := 0.0
var _poison_damage := 0.0
var _tick_remaining := 0.0

@onready var health: HealthComponent = get_parent().get_node("HealthComponent")


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_freeze_remaining = maxf(_freeze_remaining - delta, 0.0)
	var was_stunned := _stun_remaining > 0.0
	_stun_remaining = maxf(_stun_remaining - delta, 0.0)
	movement_multiplier = 0.0 if _stun_remaining > 0.0 else (0.18 if _freeze_remaining > 0.0 else 1.0)
	if was_stunned != (_stun_remaining > 0.0):
		stun_changed.emit(_stun_remaining > 0.0)
	_burn_remaining = maxf(_burn_remaining - delta, 0.0)
	_poison_remaining = maxf(_poison_remaining - delta, 0.0)
	if _burn_remaining <= 0.0:
		_burn_damage = 0.0
	if _poison_remaining <= 0.0:
		_poison_damage = 0.0
	_tick_remaining -= delta
	if _tick_remaining <= 0.0:
		_tick_remaining = 0.5
		if _burn_remaining > 0.0:
			health.take_damage(_burn_damage * 0.5)
		if _poison_remaining > 0.0:
			health.take_damage(_poison_damage * 0.5)
	if _freeze_remaining <= 0.0 and _stun_remaining <= 0.0 and _burn_remaining <= 0.0 and _poison_remaining <= 0.0:
		_tick_remaining = 0.0
		set_physics_process(false)


func apply_effects(effects: Array[Dictionary], duration_multiplier: float = 1.0) -> void:
	if effects.is_empty():
		return
	set_physics_process(true)
	for effect in effects:
		var duration := float(effect.get("duration", 1.0)) * duration_multiplier
		match String(effect.get("type", "")):
			"freeze":
				_freeze_remaining = maxf(_freeze_remaining, duration)
			"stun":
				var was_stunned := _stun_remaining > 0.0
				_stun_remaining = maxf(_stun_remaining, duration)
				movement_multiplier = 0.0
				if not was_stunned:
					stun_changed.emit(true)
			"burn":
				_burn_remaining = maxf(_burn_remaining, duration)
				_burn_damage = maxf(_burn_damage, float(effect.get("damage", 1.0)))
			"poison":
				_poison_remaining = maxf(_poison_remaining, duration)
				_poison_damage += float(effect.get("damage", 1.0))


func is_stunned() -> bool:
	return _stun_remaining > 0.0


func is_frozen() -> bool:
	return _freeze_remaining > 0.0
