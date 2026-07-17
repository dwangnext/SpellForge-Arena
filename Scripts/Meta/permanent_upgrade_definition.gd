class_name PermanentUpgradeDefinition
extends Resource

enum EffectType { HEALTH, MOVEMENT_SPEED, SPELL_DAMAGE, SPELL_COOLDOWN, COIN_GAIN }

@export var id := "permanent_upgrade"
@export var display_name := "Permanent Upgrade"
@export_multiline var description := ""
@export var effect_type := EffectType.HEALTH
@export_range(0.0, 10.0, 0.01) var value_per_rank := 0.05
@export_range(1, 100, 1) var maximum_rank := 10
@export_range(0, 1000000, 1) var base_cost := 25
@export_range(1.0, 10.0, 0.05) var cost_growth := 1.6


func cost_for_rank(current_rank: int) -> int:
	return maxi(roundi(base_cost * pow(cost_growth, current_rank)), 1)
