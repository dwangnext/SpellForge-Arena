class_name FusionRecipe
extends Resource

enum GrantedStatus { NONE, FREEZE, BURN, POISON }

@export_category("Identity")
@export var id := "fusion"
@export var display_name := "Fusion"
@export_multiline var description := ""
@export_range(0, 1000, 1) var priority := 0

@export_category("Conditions")
@export var component_spell_ids := PackedStringArray()
@export var required_upgrade_ids := PackedStringArray()
@export var required_upgrade_tags := PackedStringArray()
@export_range(0.1, 30.0, 0.1) var combination_window := 5.0

@export_category("Result")
@export var output_spell: SpellDefinition
@export_range(0.1, 20.0, 0.05) var damage_multiplier := 1.0
@export_range(1, 20, 1) var minimum_projectiles := 1
@export var granted_status := GrantedStatus.NONE
@export_range(0.0, 1000.0, 0.5) var status_damage := 0.0
@export_range(0.0, 30.0, 0.1) var status_duration := 0.0


func matches(current_spell_id: String, recent_spells: Dictionary, upgrades: UpgradeController, now_msec: int) -> bool:
	if output_spell == null or not component_spell_ids.has(current_spell_id):
		return false
	for component_id in component_spell_ids:
		if component_id == current_spell_id:
			continue
		var cast_time := int(recent_spells.get(component_id, -1))
		if cast_time < 0 or now_msec - cast_time > roundi(combination_window * 1000.0):
			return false
	for upgrade_id in required_upgrade_ids:
		if upgrades == null or not upgrades.has_upgrade_id(upgrade_id):
			return false
	for upgrade_tag in required_upgrade_tags:
		if upgrades == null or not upgrades.has_fusion_tag(upgrade_tag):
			return false
	return true


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.strip_edges().is_empty():
		errors.append("Recipe ID is required.")
	if display_name.strip_edges().is_empty():
		errors.append("Display name is required.")
	if component_spell_ids.is_empty():
		errors.append("At least one component spell is required.")
	var unique_components: Dictionary = {}
	for component_id in component_spell_ids:
		if component_id.strip_edges().is_empty():
			errors.append("Component spell IDs cannot be empty.")
		elif unique_components.has(component_id):
			errors.append("Component spell IDs must be unique.")
		unique_components[component_id] = true
	if output_spell == null:
		errors.append("Output spell is required.")
	if granted_status != GrantedStatus.NONE and status_duration <= 0.0:
		errors.append("Granted statuses require a positive duration.")
	if granted_status in [GrantedStatus.BURN, GrantedStatus.POISON] and status_damage <= 0.0:
		errors.append("Burn and poison fusions require positive status damage.")
	return errors
