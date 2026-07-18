class_name SpellCaster
extends Node

signal loadout_ready(definitions: Array[Resource])
signal selection_changed(index: int, definition: SpellDefinition)
signal cooldown_changed(index: int, remaining: float, duration: float)
signal spell_cast(definition: SpellDefinition)

@export var loadout: Array[Resource] = []
@export var spell_container_path: NodePath

var selected_index := 0
var _cooldowns: Array[float] = []
var _cooldown_durations: Array[float] = []
var _is_enabled := true


func _ready() -> void:
	_load_equipped_definitions()
	_validate_loadout()
	_reset_cooldowns()
	call_deferred("_announce_loadout")


func reload_equipped_loadout() -> void:
	_load_equipped_definitions()
	_validate_loadout()
	selected_index = 0
	_reset_cooldowns()
	_announce_loadout()


func _load_equipped_definitions() -> void:
	var equipped := MetaProgression.get_equipped_spells()
	if not equipped.is_empty():
		loadout.assign(equipped)


func _reset_cooldowns() -> void:
	_cooldowns.resize(loadout.size())
	_cooldowns.fill(0.0)
	_cooldown_durations.resize(loadout.size())
	_cooldown_durations.fill(0.0)


func _process(delta: float) -> void:
	_update_cooldowns(delta)
	if not _is_enabled:
		return
	var requested_slot := InputManager.get_requested_spell_slot()
	if requested_slot >= 0 and requested_slot < loadout.size():
		select_spell(requested_slot)
	var cycle_direction := InputManager.get_spell_cycle_direction()
	if cycle_direction != 0 and not loadout.is_empty():
		select_spell(posmod(selected_index + cycle_direction, loadout.size()))
	if InputManager.is_primary_attack_pressed():
		try_cast_selected()


func select_spell(index: int) -> void:
	if index < 0 or index >= loadout.size():
		return
	var requested := loadout[index] as SpellDefinition
	if requested == null or MetaProgression.get_equippable_spell(requested.id) == null:
		return
	selected_index = index
	selection_changed.emit(selected_index, loadout[selected_index] as SpellDefinition)


func set_combat_enabled(is_enabled: bool) -> void:
	_is_enabled = is_enabled


func try_cast_selected() -> bool:
	if selected_index >= loadout.size() or _cooldowns[selected_index] > 0.0:
		return false
	var selected := loadout[selected_index] as SpellDefinition
	if selected == null or selected.spell_scene == null or MetaProgression.get_equippable_spell(selected.id) == null:
		return false
	var owner_2d := get_parent() as Node2D
	var container := get_node_or_null(spell_container_path)
	if owner_2d == null or container == null:
		return false
	var target := InputManager.get_aim_position(get_viewport())
	var upgrade_controller := owner_2d.get_node_or_null("UpgradeController") as UpgradeController
	var run_modifiers := upgrade_controller.create_spell_modifiers() if upgrade_controller != null else SpellModifiers.new()
	var base_modifiers := MetaProgression.apply_spell_modifiers(run_modifiers)
	if MetaProgression.is_fusion_spell_id(selected.id):
		base_modifiers.damage_multiplier *= MetaProgression.get_fusion_damage_multiplier(selected.id)
	var fusion_controller := owner_2d.get_node_or_null("FusionController") as FusionController
	var resolution := fusion_controller.resolve_cast(selected, base_modifiers, upgrade_controller) if fusion_controller != null else FusionResolution.new(selected, base_modifiers)
	var effective_spell := resolution.spell
	var modifiers := resolution.modifiers
	NetworkManager.broadcast_spell_cast(effective_spell.id, owner_2d.global_position, target, modifiers)
	var first_spell := effective_spell.spell_scene.instantiate() as Spell
	if first_spell == null:
		push_error("Spell scene must inherit from Spell.")
		return false
	var projectile_count := maxi(1 + modifiers.extra_projectiles, 1) if first_spell.supports_projectile_modifiers() else 1
	for projectile_index in range(projectile_count):
		var spell: Spell = first_spell
		if projectile_index > 0:
			spell = effective_spell.spell_scene.instantiate() as Spell
		if spell == null:
			push_error("Spell scene must inherit from Spell.")
			return false
		var spread := deg_to_rad(8.0) * (projectile_index - (projectile_count - 1) * 0.5)
		var offset_target := owner_2d.global_position + (target - owner_2d.global_position).rotated(spread)
		spell.configure(effective_spell, owner_2d, owner_2d.global_position, offset_target, modifiers)
		spell.sound_enabled = projectile_index == 0
		container.add_child(spell)
		spell.activate()
	var effective_cooldown := effective_spell.cooldown * modifiers.cooldown_multiplier
	_cooldowns[selected_index] = effective_cooldown
	_cooldown_durations[selected_index] = effective_cooldown
	cooldown_changed.emit(selected_index, effective_cooldown, effective_cooldown)
	spell_cast.emit(effective_spell)
	MetaProgression.record_stat("spells_cast")
	return true


func _update_cooldowns(delta: float) -> void:
	for index in range(_cooldowns.size()):
		if _cooldowns[index] <= 0.0:
			continue
		_cooldowns[index] = maxf(_cooldowns[index] - delta, 0.0)
		cooldown_changed.emit(index, _cooldowns[index], _cooldown_durations[index])


func _announce_loadout() -> void:
	loadout_ready.emit(loadout)
	if not loadout.is_empty():
		selection_changed.emit(selected_index, loadout[selected_index] as SpellDefinition)


func _validate_loadout() -> void:
	var known_ids: Dictionary = {}
	for resource in loadout:
		var spell_definition := resource as SpellDefinition
		if spell_definition == null:
			push_error("Spell loadout contains a resource that is not a SpellDefinition.")
			continue
		for error in spell_definition.get_validation_errors():
			push_error("%s: %s" % [spell_definition.display_name, error])
		if known_ids.has(spell_definition.id):
			push_error("Duplicate spell loadout ID: %s" % spell_definition.id)
		known_ids[spell_definition.id] = true
