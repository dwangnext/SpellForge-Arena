class_name SpellModifiers
extends RefCounted

var damage_multiplier := 1.0
var cooldown_multiplier := 1.0
var projectile_speed_multiplier := 1.0
var area_multiplier := 1.0
var critical_chance := 0.0
var critical_multiplier := 2.0
var extra_projectiles := 0
var bounce_count := 0
var pierce_bonus := 0
var freeze_chance := 0.0
var freeze_duration := 0.0
var burn_chance := 0.0
var burn_damage := 0.0
var burn_duration := 3.0
var poison_chance := 0.0
var poison_damage := 0.0
var poison_duration := 4.0
var homing_enabled := false
var homing_strength_bonus := 0.0


func duplicate_snapshot() -> SpellModifiers:
	var copy := SpellModifiers.new()
	copy.damage_multiplier = damage_multiplier
	copy.cooldown_multiplier = cooldown_multiplier
	copy.projectile_speed_multiplier = projectile_speed_multiplier
	copy.area_multiplier = area_multiplier
	copy.critical_chance = critical_chance
	copy.critical_multiplier = critical_multiplier
	copy.extra_projectiles = extra_projectiles
	copy.bounce_count = bounce_count
	copy.pierce_bonus = pierce_bonus
	copy.freeze_chance = freeze_chance
	copy.freeze_duration = freeze_duration
	copy.burn_chance = burn_chance
	copy.burn_damage = burn_damage
	copy.burn_duration = burn_duration
	copy.poison_chance = poison_chance
	copy.poison_damage = poison_damage
	copy.poison_duration = poison_duration
	copy.homing_enabled = homing_enabled
	copy.homing_strength_bonus = homing_strength_bonus
	return copy
