class_name UpgradeDefinition
extends Resource

enum EffectType {
	DAMAGE,
	COOLDOWN,
	PROJECTILE_SPEED,
	AREA_SIZE,
	CRITICAL_HIT,
	EXTRA_PROJECTILE,
	BOUNCE,
	PIERCE,
	FREEZE,
	BURN,
	POISON,
	HOMING,
	LIFESTEAL
}

@export var id := "upgrade"
@export var display_name := "Upgrade"
@export_multiline var description := ""
@export var effect_type := EffectType.DAMAGE
@export var fusion_tags := PackedStringArray()
@export_range(0.0, 100.0, 0.01) var magnitude := 0.1
@export_range(0.0, 100.0, 0.01) var secondary_magnitude := 0.0
@export_range(1, 100, 1) var maximum_stacks := 5
@export_range(0.01, 100.0, 0.01) var selection_weight := 1.0
@export var accent_color := Color("8e7dff")


func format_description() -> String:
	return description.replace("{value}", str(roundi(magnitude * 100.0))).replace("{secondary}", str(secondary_magnitude))
