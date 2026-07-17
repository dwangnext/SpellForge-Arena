class_name UpgradeController
extends Node

signal upgrade_applied(definition: UpgradeDefinition, stack_count: int)

@export var catalog: Array[Resource] = []

var _stacks: Dictionary = {}
var _cached_modifiers := SpellModifiers.new()
var _modifier_cache_dirty := true
var _active_fusion_tags: Dictionary = {}


func _ready() -> void:
	_validate_catalog()


func get_random_choices(count: int) -> Array[UpgradeDefinition]:
	var pool := get_available_upgrades()
	var choices: Array[UpgradeDefinition] = []
	while not pool.is_empty() and choices.size() < count:
		var selected_index := _weighted_index(pool)
		choices.append(pool[selected_index])
		pool.remove_at(selected_index)
	return choices


func get_available_upgrades() -> Array[UpgradeDefinition]:
	var pool: Array[UpgradeDefinition] = []
	for resource in catalog:
		var definition := resource as UpgradeDefinition
		if definition != null and get_stack_count(definition) < MetaProgression.get_upgrade_cap(definition):
			pool.append(definition)
	return pool


func apply_upgrade(definition: UpgradeDefinition) -> bool:
	if definition == null or get_stack_count(definition) >= MetaProgression.get_upgrade_cap(definition):
		return false
	_stacks[definition.id] = get_stack_count(definition) + 1
	for tag in definition.fusion_tags:
		_active_fusion_tags[tag] = true
	_modifier_cache_dirty = true
	upgrade_applied.emit(definition, get_stack_count(definition))
	return true


func get_stack_count(definition: UpgradeDefinition) -> int:
	return int(_stacks.get(definition.id, 0))


func has_upgrade_id(upgrade_id: String) -> bool:
	return int(_stacks.get(upgrade_id, 0)) > 0


func has_fusion_tag(tag: String) -> bool:
	return _active_fusion_tags.has(tag)


func create_spell_modifiers() -> SpellModifiers:
	if not _modifier_cache_dirty:
		return _cached_modifiers
	var modifiers := SpellModifiers.new()
	for resource in catalog:
		var definition := resource as UpgradeDefinition
		if definition == null:
			continue
		var stacks := get_stack_count(definition)
		if stacks <= 0:
			continue
		_apply_to_snapshot(modifiers, definition, stacks)
	_cached_modifiers = modifiers
	_modifier_cache_dirty = false
	return _cached_modifiers


func _apply_to_snapshot(modifiers: SpellModifiers, upgrade: UpgradeDefinition, stacks: int) -> void:
	var total := upgrade.magnitude * stacks
	match upgrade.effect_type:
		UpgradeDefinition.EffectType.DAMAGE: modifiers.damage_multiplier += total
		UpgradeDefinition.EffectType.COOLDOWN: modifiers.cooldown_multiplier = maxf(0.15, modifiers.cooldown_multiplier - total)
		UpgradeDefinition.EffectType.PROJECTILE_SPEED: modifiers.projectile_speed_multiplier += total
		UpgradeDefinition.EffectType.AREA_SIZE: modifiers.area_multiplier += total
		UpgradeDefinition.EffectType.CRITICAL_HIT:
			modifiers.critical_chance += total
			modifiers.critical_multiplier = maxf(upgrade.secondary_magnitude, 2.0)
		UpgradeDefinition.EffectType.EXTRA_PROJECTILE: modifiers.extra_projectiles += roundi(upgrade.magnitude) * stacks
		UpgradeDefinition.EffectType.BOUNCE: modifiers.bounce_count += roundi(upgrade.magnitude) * stacks
		UpgradeDefinition.EffectType.PIERCE: modifiers.pierce_bonus += roundi(upgrade.magnitude) * stacks
		UpgradeDefinition.EffectType.FREEZE:
			modifiers.freeze_chance += total
			modifiers.freeze_duration = maxf(modifiers.freeze_duration, upgrade.secondary_magnitude)
		UpgradeDefinition.EffectType.BURN:
			modifiers.burn_chance += minf(total, 1.0)
			modifiers.burn_damage += upgrade.secondary_magnitude * stacks
		UpgradeDefinition.EffectType.POISON:
			modifiers.poison_chance += minf(total, 1.0)
			modifiers.poison_damage += upgrade.secondary_magnitude * stacks
		UpgradeDefinition.EffectType.HOMING:
			modifiers.homing_enabled = true
			modifiers.homing_strength_bonus += upgrade.magnitude * stacks
		UpgradeDefinition.EffectType.LIFESTEAL:
			pass


func _weighted_index(pool: Array[UpgradeDefinition]) -> int:
	var total_weight := 0.0
	for item in pool:
		total_weight += item.selection_weight
	var roll := randf() * total_weight
	for index in range(pool.size()):
		roll -= pool[index].selection_weight
		if roll <= 0.0:
			return index
	return pool.size() - 1


func _validate_catalog() -> void:
	var known_ids: Dictionary = {}
	for resource in catalog:
		var definition := resource as UpgradeDefinition
		if definition == null:
			push_error("Upgrade catalog contains a non-upgrade resource.")
			continue
		if definition.id.strip_edges().is_empty():
			push_error("Upgrade IDs cannot be empty.")
		elif known_ids.has(definition.id):
			push_error("Duplicate upgrade ID: %s" % definition.id)
		known_ids[definition.id] = true
