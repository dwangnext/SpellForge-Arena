class_name FusionController
extends Node

signal fusion_activated(recipe: FusionRecipe)

@export var recipes: Array[Resource] = []
@export var automatic_fusions_enabled := false

var _recipes_by_component: Dictionary = {}
var _recent_spells: Dictionary = {}
var _maximum_window_msec := 5000
var _game_time_msec := 0.0


func _ready() -> void:
	_rebuild_database()


func _process(delta: float) -> void:
	_game_time_msec += delta * 1000.0


func resolve_cast(requested: SpellDefinition, base_modifiers: SpellModifiers, upgrades: UpgradeController) -> FusionResolution:
	# Purchased fusions are equipped directly; recipes are no longer discovered during a run.
	if not automatic_fusions_enabled:
		return FusionResolution.new(requested, base_modifiers)
	var now := roundi(_game_time_msec)
	_prune_history(now)
	var candidates: Array = _recipes_by_component.get(requested.id, [])
	for resource in candidates:
		var recipe := resource as FusionRecipe
		if recipe == null:
			continue
		if recipe.component_spell_ids.size() == 2 and not MetaProgression.is_fusion_unlocked(recipe.id):
			continue
		if not recipe.matches(requested.id, _recent_spells, upgrades, now):
			continue
		var fused_modifiers := _apply_recipe_modifiers(base_modifiers, recipe)
		_consume_components(recipe)
		if recipe.component_spell_ids.size() == 1:
			_recent_spells[requested.id] = now
		MetaProgression.record_stat("fusions_activated")
		CameraEffects.flash(recipe.output_spell.primary_color, 0.2, 0.2)
		fusion_activated.emit(recipe)
		return FusionResolution.new(recipe.output_spell, fused_modifiers, recipe)
	_recent_spells[requested.id] = now
	return FusionResolution.new(requested, base_modifiers)


func _rebuild_database() -> void:
	_recipes_by_component.clear()
	_maximum_window_msec = 100
	var known_ids: Dictionary = {}
	var known_output_ids: Dictionary = {}
	for resource in recipes:
		var recipe := resource as FusionRecipe
		if recipe == null or recipe.output_spell == null:
			push_error("Fusion database contains an invalid recipe resource.")
			continue
		for error in recipe.get_validation_errors():
			push_error("%s: %s" % [recipe.display_name, error])
		for error in recipe.output_spell.get_validation_errors():
			push_error("%s output: %s" % [recipe.display_name, error])
		if known_ids.has(recipe.id):
			push_error("Duplicate fusion recipe ID: %s" % recipe.id)
			continue
		known_ids[recipe.id] = true
		if known_output_ids.has(recipe.output_spell.id):
			push_error("Duplicate fusion output spell ID: %s" % recipe.output_spell.id)
			continue
		known_output_ids[recipe.output_spell.id] = true
		for component_id in recipe.component_spell_ids:
			var bucket: Array = _recipes_by_component.get(component_id, [])
			bucket.append(recipe)
			_recipes_by_component[component_id] = bucket
		_maximum_window_msec = maxi(_maximum_window_msec, roundi(recipe.combination_window * 1000.0))
	for component_id in _recipes_by_component:
		var bucket: Array = _recipes_by_component[component_id]
		bucket.sort_custom(_sort_by_priority)
	_validate_component_references()


func _apply_recipe_modifiers(base: SpellModifiers, recipe: FusionRecipe) -> SpellModifiers:
	var result := base.duplicate_snapshot()
	result.damage_multiplier *= recipe.damage_multiplier
	result.extra_projectiles = maxi(result.extra_projectiles, recipe.minimum_projectiles - 1)
	match recipe.granted_status:
		FusionRecipe.GrantedStatus.FREEZE:
			result.freeze_chance = 1.0
			result.freeze_duration = maxf(result.freeze_duration, recipe.status_duration)
		FusionRecipe.GrantedStatus.BURN:
			result.burn_chance = 1.0
			result.burn_damage = maxf(result.burn_damage, recipe.status_damage)
			result.burn_duration = maxf(result.burn_duration, recipe.status_duration)
		FusionRecipe.GrantedStatus.POISON:
			result.poison_chance = 1.0
			result.poison_damage = maxf(result.poison_damage, recipe.status_damage)
			result.poison_duration = maxf(result.poison_duration, recipe.status_duration)
	return result


func _sort_by_priority(a: FusionRecipe, b: FusionRecipe) -> bool:
	return a.priority > b.priority


func _consume_components(recipe: FusionRecipe) -> void:
	for component_id in recipe.component_spell_ids:
		_recent_spells.erase(component_id)


func _prune_history(now_msec: int) -> void:
	for spell_id in _recent_spells.keys():
		if now_msec - int(_recent_spells[spell_id]) > _maximum_window_msec:
			_recent_spells.erase(spell_id)


func _validate_component_references() -> void:
	var known_spell_ids: Dictionary = {}
	for spell in MetaProgression.spells:
		known_spell_ids[spell.id] = true
	for resource in recipes:
		var recipe := resource as FusionRecipe
		if recipe != null and recipe.output_spell != null:
			known_spell_ids[recipe.output_spell.id] = true
	for resource in recipes:
		var recipe := resource as FusionRecipe
		if recipe == null:
			continue
		for component_id in recipe.component_spell_ids:
			if not known_spell_ids.has(component_id):
				push_error("%s references unknown spell ID: %s" % [recipe.display_name, component_id])
