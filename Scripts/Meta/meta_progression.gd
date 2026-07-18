extends Node

signal profile_changed
signal coins_changed(amount: int)
signal achievement_unlocked(definition: AchievementDefinition)
signal character_selected(definition: CharacterDefinition)
signal weapon_selected(weapon_id: String)

const SAVE_VERSION := 7
const SAVE_PATH := "user://spellforge_profile.json"
const MAX_UPGRADE_CAP_EXTENSIONS := 3
const WEAPON_IDS: Array[String] = ["wand", "revolver", "gauntlet"]
const WEAPON_DATA := {
	"wand": {"name": "Spellforge Wand", "cost": 0, "power": 3, "description": "Flexible elements, area control, and fusion spells"},
	"revolver": {"name": "Arcane Revolver", "cost": 10000, "power": 4, "description": "Rapid salvos, rail rounds, and stunning ammunition"},
	"gauntlet": {"name": "Rift Gauntlet", "cost": 18000, "power": 5, "description": "Dragonfire, time traps, teleport slashes, and singularities"},
}

var meta_coins := 0
var permanent_ranks: Dictionary = {}
var unlocked_characters: Dictionary = {}
var unlocked_spells: Dictionary = {}
var unlocked_fusions: Dictionary = {}
var collected_relics: Dictionary = {}
var unlocked_achievements: Dictionary = {}
var statistics: Dictionary = {}
var selected_character_id := "arcanist"
var selected_weapon_id := "wand"
var unlocked_weapons: Dictionary = {"wand": true}
var equipped_spell_ids: Array[String] = []
var upgrade_cap_extensions: Dictionary = {}
var player_code := ""

var permanent_upgrades: Array[PermanentUpgradeDefinition] = []
var characters: Array[CharacterDefinition] = []
var achievements: Array[AchievementDefinition] = []
var relics: Array[RelicDefinition] = []
var spells: Array[SpellDefinition] = []
var fusion_recipes: Array[FusionRecipe] = []
var run_upgrades: Array[UpgradeDefinition] = []

var _permanent_effect_totals: Dictionary = {}
var _save_timer: Timer
var _play_time_accumulator := 0.0
var _play_time_save_accumulator := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.4
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer.timeout.connect(save_profile)
	add_child(_save_timer)
	_load_catalogs()
	_validate_catalogs()
	_load_profile()
	_ensure_player_code()
	_apply_catalog_defaults()
	_ensure_valid_equipped_spells()
	_rebuild_effect_cache()
	_evaluate_achievements()


func _process(delta: float) -> void:
	_play_time_accumulator += delta
	_play_time_save_accumulator += delta
	if _play_time_accumulator >= 1.0:
		var whole_seconds := floori(_play_time_accumulator)
		statistics["play_time_seconds"] = get_stat("play_time_seconds") + whole_seconds
		_play_time_accumulator -= whole_seconds
	if _play_time_save_accumulator >= 10.0:
		_play_time_save_accumulator = 0.0
		_commit_change()


func add_coins(base_amount: int) -> int:
	if base_amount <= 0:
		return 0
	var multiplier := 1.0 + get_permanent_effect(PermanentUpgradeDefinition.EffectType.COIN_GAIN)
	var awarded := maxi(roundi(base_amount * multiplier), 1)
	meta_coins += awarded
	record_stat("coins_collected", awarded, false)
	coins_changed.emit(meta_coins)
	_commit_change()
	return awarded


func grant_coins(amount: int) -> void:
	if amount <= 0:
		return
	meta_coins += amount
	coins_changed.emit(meta_coins)
	_commit_change()


func spend_coins(amount: int) -> bool:
	if not _deduct_coins(amount):
		return false
	record_stat("coins_spent", amount, false)
	coins_changed.emit(meta_coins)
	_commit_change()
	return true


func purchase_permanent_upgrade(definition: PermanentUpgradeDefinition) -> bool:
	if definition == null:
		return false
	var current_rank := get_permanent_rank(definition.id)
	if current_rank >= definition.maximum_rank:
		return false
	var cost := definition.cost_for_rank(current_rank)
	if not _deduct_coins(cost):
		return false
	permanent_ranks[definition.id] = current_rank + 1
	record_stat("coins_spent", cost, false)
	coins_changed.emit(meta_coins)
	_rebuild_effect_cache()
	_commit_change()
	return true


func get_permanent_rank(upgrade_id: String) -> int:
	return int(permanent_ranks.get(upgrade_id, 0))


func get_permanent_effect(effect_type: PermanentUpgradeDefinition.EffectType) -> float:
	return float(_permanent_effect_totals.get(effect_type, 0.0))


func unlock_character(character_id: String) -> bool:
	var definition := get_character(character_id)
	if definition == null or unlocked_characters.has(character_id):
		return false
	if not _deduct_coins(definition.unlock_cost):
		return false
	unlocked_characters[character_id] = true
	record_stat("coins_spent", definition.unlock_cost, false)
	coins_changed.emit(meta_coins)
	_commit_change()
	return true


func select_character(character_id: String) -> bool:
	var definition := get_character(character_id)
	if definition == null or not unlocked_characters.has(character_id):
		return false
	selected_character_id = character_id
	character_selected.emit(definition)
	_commit_change()
	return true


func get_character(character_id: String) -> CharacterDefinition:
	for definition in characters:
		if definition.id == character_id:
			return definition
	return null


func get_selected_character() -> CharacterDefinition:
	var selected := get_character(selected_character_id)
	return selected if selected != null else (characters[0] if not characters.is_empty() else null)


func select_weapon(weapon_id: String) -> bool:
	if not weapon_id in WEAPON_IDS or not is_weapon_unlocked(weapon_id):
		return false
	if selected_weapon_id == weapon_id:
		return true
	selected_weapon_id = weapon_id
	equipped_spell_ids.clear()
	weapon_selected.emit(selected_weapon_id)
	_commit_change()
	return true


func is_weapon_unlocked(weapon_id: String) -> bool:
	return unlocked_weapons.has(weapon_id)


func purchase_weapon(weapon_id: String) -> bool:
	if not weapon_id in WEAPON_IDS or weapon_id == "wand" or is_weapon_unlocked(weapon_id):
		return false
	var cost := get_weapon_unlock_cost(weapon_id)
	if not _deduct_coins(cost):
		return false
	unlocked_weapons[weapon_id] = true
	record_stat("coins_spent", cost, false)
	coins_changed.emit(meta_coins)
	_commit_change()
	return true


func unlock_spell(spell_id: String) -> bool:
	if unlocked_spells.has(spell_id):
		return false
	var definition := _get_spell(spell_id)
	if definition != null and definition.weapon_id != "wand" and not is_weapon_unlocked(definition.weapon_id):
		return false
	if definition == null or not _deduct_coins(definition.unlock_cost):
		return false
	unlocked_spells[spell_id] = true
	record_stat("coins_spent", definition.unlock_cost, false)
	coins_changed.emit(meta_coins)
	_commit_change()
	return true


func is_spell_unlocked(spell_id: String) -> bool:
	return unlocked_spells.has(spell_id)


func get_weapon_display_name(weapon_id: String) -> String:
	return String((WEAPON_DATA.get(weapon_id, WEAPON_DATA["wand"]) as Dictionary).get("name", "Weapon"))


func get_weapon_description(weapon_id: String) -> String:
	return String((WEAPON_DATA.get(weapon_id, WEAPON_DATA["wand"]) as Dictionary).get("description", ""))


func get_weapon_unlock_cost(weapon_id: String) -> int:
	return int((WEAPON_DATA.get(weapon_id, {}) as Dictionary).get("cost", 0))


func get_weapon_power(weapon_id: String) -> int:
	return int((WEAPON_DATA.get(weapon_id, WEAPON_DATA["wand"]) as Dictionary).get("power", 1))


func get_weapon_power_circles(weapon_id: String) -> String:
	var result := ""
	for index in range(5):
		# ASCII circles remain legible in Godot's browser fallback font.
		result += "O" if index < get_weapon_power(weapon_id) else "o"
	return result


func unlock_everything() -> void:
	for weapon_id in WEAPON_IDS:
		unlocked_weapons[weapon_id] = true
	for spell in spells:
		unlocked_spells[spell.id] = true
	for recipe in fusion_recipes:
		unlocked_fusions[recipe.id] = true
	_commit_change()


func set_player_code(code: String) -> bool:
	var cleaned := code.strip_edges()
	if cleaned.length() != 6 or not cleaned.is_valid_int():
		return false
	player_code = cleaned
	_commit_change()
	return true


func get_fusion_cost(recipe: FusionRecipe) -> int:
	if recipe == null or recipe.component_spell_ids.size() != 2:
		return 0
	var combined_cost := 0
	for spell_id in recipe.component_spell_ids:
		var component := _get_spell(spell_id)
		if component == null:
			return 0
		combined_cost += component.unlock_cost
	return ceili(combined_cost * 1.75) + 25


func can_purchase_fusion(recipe: FusionRecipe) -> bool:
	if recipe == null or unlocked_fusions.has(recipe.id) or recipe.component_spell_ids.size() != 2:
		return false
	for spell_id in recipe.component_spell_ids:
		if not is_spell_unlocked(spell_id):
			return false
	return meta_coins >= get_fusion_cost(recipe)


func purchase_fusion(recipe: FusionRecipe) -> bool:
	if not can_purchase_fusion(recipe):
		return false
	var cost := get_fusion_cost(recipe)
	if not _deduct_coins(cost):
		return false
	unlocked_fusions[recipe.id] = true
	record_stat("coins_spent", cost, false)
	record_stat("fusions_forged", 1, false)
	coins_changed.emit(meta_coins)
	_commit_change()
	return true


func is_fusion_unlocked(fusion_id: String) -> bool:
	return unlocked_fusions.has(fusion_id)


func get_available_equippable_spells() -> Array[SpellDefinition]:
	var available: Array[SpellDefinition] = []
	for spell in spells:
		if is_spell_unlocked(spell.id) and spell.weapon_id == selected_weapon_id:
			available.append(spell)
	if selected_weapon_id == "wand":
		for recipe in fusion_recipes:
			if recipe.output_spell != null and is_fusion_unlocked(recipe.id):
				available.append(recipe.output_spell)
	return available


func get_equipped_spells() -> Array[SpellDefinition]:
	var equipped: Array[SpellDefinition] = []
	for spell_id in equipped_spell_ids:
		var spell := get_equippable_spell(spell_id)
		if spell != null and spell.weapon_id == selected_weapon_id:
			equipped.append(spell)
	return equipped


func set_equipped_spells(spell_ids: Array[String]) -> bool:
	if spell_ids.is_empty() or spell_ids.size() > 6:
		return false
	var valid_ids: Array[String] = []
	for spell_id in spell_ids:
		var definition := get_equippable_spell(spell_id)
		if valid_ids.has(spell_id) or definition == null or definition.weapon_id != selected_weapon_id:
			return false
		valid_ids.append(spell_id)
	equipped_spell_ids = valid_ids
	_commit_change()
	return true


func get_equippable_spell(spell_id: String) -> SpellDefinition:
	if is_spell_unlocked(spell_id):
		var base_spell := _get_spell(spell_id)
		if base_spell != null:
			return base_spell
	for recipe in fusion_recipes:
		if recipe.output_spell != null and recipe.output_spell.id == spell_id and is_fusion_unlocked(recipe.id):
			return recipe.output_spell
	return null


func find_spell_definition(spell_id: String) -> SpellDefinition:
	var base_spell := _get_spell(spell_id)
	if base_spell != null:
		return base_spell
	for recipe in fusion_recipes:
		if recipe.output_spell != null and recipe.output_spell.id == spell_id:
			return recipe.output_spell
	return null


func is_fusion_spell_id(spell_id: String) -> bool:
	for recipe in fusion_recipes:
		if recipe.output_spell != null and recipe.output_spell.id == spell_id:
			return true
	return false


func get_fusion_damage_multiplier(spell_id: String) -> float:
	for recipe in fusion_recipes:
		if recipe.output_spell != null and recipe.output_spell.id == spell_id:
			return recipe.damage_multiplier * 1.25
	return 1.0


func get_upgrade_cap(definition: UpgradeDefinition) -> int:
	return definition.maximum_stacks + int(upgrade_cap_extensions.get(definition.id, 0))


func get_upgrade_cap_extension(definition: UpgradeDefinition) -> int:
	return int(upgrade_cap_extensions.get(definition.id, 0))


func get_upgrade_cap_cost(definition: UpgradeDefinition) -> int:
	var extension := get_upgrade_cap_extension(definition)
	return 40 + definition.maximum_stacks * 4 + extension * 30


func purchase_upgrade_cap(definition: UpgradeDefinition) -> bool:
	if definition == null or get_upgrade_cap_extension(definition) >= MAX_UPGRADE_CAP_EXTENSIONS:
		return false
	var cost := get_upgrade_cap_cost(definition)
	if not _deduct_coins(cost):
		return false
	upgrade_cap_extensions[definition.id] = get_upgrade_cap_extension(definition) + 1
	record_stat("coins_spent", cost, false)
	coins_changed.emit(meta_coins)
	_commit_change()
	return true


func collect_relic(relic_id: String) -> bool:
	if relic_id.is_empty() or collected_relics.has(relic_id):
		return false
	collected_relics[relic_id] = true
	record_stat("relics_collected", 1, false)
	_commit_change()
	return true


func record_stat(key: String, amount: int = 1, save_immediately: bool = true) -> void:
	statistics[key] = int(statistics.get(key, 0)) + amount
	_evaluate_achievements()
	if save_immediately:
		_commit_change()


func set_stat_max(key: String, value: int) -> void:
	if value <= int(statistics.get(key, 0)):
		return
	statistics[key] = value
	_evaluate_achievements()
	_commit_change()


func get_stat(key: String) -> int:
	return int(statistics.get(key, 0))


func apply_spell_modifiers(base: SpellModifiers) -> SpellModifiers:
	var result := base.duplicate_snapshot()
	result.damage_multiplier *= 1.0 + get_permanent_effect(PermanentUpgradeDefinition.EffectType.SPELL_DAMAGE)
	result.cooldown_multiplier *= maxf(0.2, 1.0 - get_permanent_effect(PermanentUpgradeDefinition.EffectType.SPELL_COOLDOWN))
	var character := get_selected_character()
	if character != null:
		result.damage_multiplier *= character.damage_multiplier
		result.cooldown_multiplier *= character.cooldown_multiplier
	return result


func save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Unable to save long-term progression profile.")
		return
	file.store_string(JSON.stringify(_serialize(), "\t"))


func reset_profile() -> void:
	meta_coins = 0
	permanent_ranks.clear()
	unlocked_characters.clear()
	unlocked_spells.clear()
	unlocked_fusions.clear()
	equipped_spell_ids.clear()
	upgrade_cap_extensions.clear()
	collected_relics.clear()
	unlocked_achievements.clear()
	statistics.clear()
	selected_character_id = "arcanist"
	selected_weapon_id = "wand"
	unlocked_weapons = {"wand": true}
	_apply_catalog_defaults()
	_ensure_valid_equipped_spells()
	_rebuild_effect_cache()
	_commit_change()


func _load_catalogs() -> void:
	permanent_upgrades.assign(_load_resources("res://Resources/PermanentUpgrades"))
	characters.assign(_load_resources("res://Resources/Characters"))
	achievements.assign(_load_resources("res://Resources/Achievements"))
	relics.assign(_load_resources("res://Resources/Relics"))
	spells.assign(_load_resources("res://Resources/Spells"))
	fusion_recipes.assign(_load_resources("res://Resources/Fusions"))
	run_upgrades.assign(_load_resources("res://Resources/Upgrades"))
	_generate_missing_pair_fusions()


func _load_resources(directory_path: String) -> Array[Resource]:
	var loaded: Array[Resource] = []
	# ResourceLoader preserves original resource names inside exported PCK files,
	# while DirAccess can expose only the generated `.remap` names on Web.
	for file_name in ResourceLoader.list_directory(directory_path):
		if file_name.ends_with(".tres"):
			var resource := load(directory_path.path_join(file_name))
			if resource != null:
				loaded.append(resource)
	return loaded


func _generate_missing_pair_fusions() -> void:
	var existing_pairs: Dictionary = {}
	for recipe in fusion_recipes:
		if recipe.component_spell_ids.size() == 2:
			existing_pairs[_pair_key(recipe.component_spell_ids[0], recipe.component_spell_ids[1])] = true
	for first_index in range(spells.size()):
		for second_index in range(first_index + 1, spells.size()):
			var first := spells[first_index]
			var second := spells[second_index]
			if not first.fusion_eligible or not second.fusion_eligible or first.weapon_id != "wand" or second.weapon_id != "wand":
				continue
			var key := _pair_key(first.id, second.id)
			if existing_pairs.has(key):
				continue
			var stronger := first if first.damage >= second.damage else second
			var output := SpellDefinition.new()
			output.id = "fusion_%s" % key
			output.display_name = "%s %s Nexus" % [_fusion_word(first.id), _fusion_word(second.id)]
			output.description = "%s and %s collapse into a dual-aspect spell with focused fusion power." % [first.display_name, second.display_name]
			output.spell_scene = stronger.spell_scene
			output.visual_style = stronger.visual_style
			output.primary_color = first.primary_color.lerp(second.primary_color, 0.5).lightened(0.12)
			output.secondary_color = second.secondary_color.lerp(first.secondary_color, 0.35)
			output.damage = lerpf(maxf(first.damage, second.damage), first.damage + second.damage, 0.55)
			output.cooldown = maxf((first.cooldown + second.cooldown) * 0.58, 0.08)
			output.cast_range = maxf(first.cast_range, second.cast_range)
			output.speed = maxf(first.speed, second.speed)
			output.area_radius = maxf(first.area_radius, second.area_radius) * 1.12
			output.knockback_force = maxf(first.knockback_force, second.knockback_force) * 1.08
			output.duration = maxf(first.duration, second.duration)
			output.tick_interval = minf(first.tick_interval, second.tick_interval)
			output.pierce_count = maxi(first.pierce_count, second.pierce_count)
			output.homing = first.homing or second.homing
			output.homing_strength = maxf(first.homing_strength, second.homing_strength)
			output.line_width = maxf(first.line_width, second.line_width)
			output.impact_delay = minf(first.impact_delay, second.impact_delay)
			output.sound_pitch_hz = (first.sound_pitch_hz + second.sound_pitch_hz) * 0.5
			output.sound_duration = maxf(first.sound_duration, second.sound_duration)
			var recipe := FusionRecipe.new()
			recipe.id = output.id
			recipe.display_name = output.display_name.to_upper()
			recipe.description = "%s + %s creates %s." % [first.display_name, second.display_name, output.display_name]
			recipe.priority = 40
			recipe.component_spell_ids = PackedStringArray([first.id, second.id])
			recipe.output_spell = output
			fusion_recipes.append(recipe)


func _pair_key(first_id: String, second_id: String) -> String:
	var ids := [first_id, second_id]
	ids.sort()
	return "%s_%s" % ids


func _fusion_word(spell_id: String) -> String:
	var words := {
		"fireball": "Ember", "ice_bolt": "Cryo", "lightning": "Storm",
		"magic_missile": "Arcane", "tornado": "Tempest", "poison_cloud": "Venom",
		"laser_beam": "Prism", "meteor": "Comet", "aether_ripper": "Aether",
		"riot_shield": "Aegis",
	}
	return String(words.get(spell_id, spell_id.capitalize().replace("_", "")))


func _load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Long-term profile was invalid; using safe defaults.")
		return
	var data := parsed as Dictionary
	var profile_version := int(data.get("version", 0))
	if profile_version > SAVE_VERSION:
		push_warning("Profile comes from a newer version; unknown fields will be preserved only after migration support is added.")
	meta_coins = maxi(int(data.get("meta_coins", 0)), 0)
	permanent_ranks = data.get("permanent_ranks", {}) as Dictionary
	unlocked_characters = data.get("unlocked_characters", {}) as Dictionary
	unlocked_spells = data.get("unlocked_spells", {}) as Dictionary
	unlocked_fusions = data.get("unlocked_fusions", {}) as Dictionary
	upgrade_cap_extensions = data.get("upgrade_cap_extensions", {}) as Dictionary
	collected_relics = data.get("collected_relics", {}) as Dictionary
	unlocked_achievements = data.get("unlocked_achievements", {}) as Dictionary
	statistics = data.get("statistics", {}) as Dictionary
	selected_character_id = String(data.get("selected_character_id", "arcanist"))
	selected_weapon_id = String(data.get("selected_weapon_id", "wand"))
	unlocked_weapons = data.get("unlocked_weapons", {"wand": true}) as Dictionary
	unlocked_weapons["wand"] = true
	player_code = String(data.get("player_code", ""))
	if not selected_weapon_id in WEAPON_IDS or not is_weapon_unlocked(selected_weapon_id):
		selected_weapon_id = "wand"
	equipped_spell_ids.clear()
	for spell_id in data.get("equipped_spell_ids", []):
		equipped_spell_ids.append(String(spell_id))
	if profile_version < 2:
		# These abilities used to be granted automatically; v2 introduces the ability shop.
		for spell_id in ["lightning", "poison_cloud", "tornado", "laser_beam", "meteor", "aether_ripper", "riot_shield"]:
			unlocked_spells.erase(spell_id)


func _apply_catalog_defaults() -> void:
	unlocked_weapons["wand"] = true
	for character in characters:
		if character.unlocked_by_default:
			unlocked_characters[character.id] = true
	for spell in spells:
		if spell.unlocked_by_default:
			unlocked_spells[spell.id] = true
	if not unlocked_characters.has(selected_character_id) and not characters.is_empty():
		selected_character_id = characters[0].id


func _ensure_player_code() -> void:
	if player_code.length() == 6 and player_code.is_valid_int():
		return
	player_code = "%06d" % randi_range(100000, 999999)
	_commit_change()


func _ensure_valid_equipped_spells() -> void:
	var valid: Array[String] = []
	for spell_id in equipped_spell_ids:
		if valid.size() >= 6:
			break
		var definition := get_equippable_spell(spell_id)
		if not valid.has(spell_id) and definition != null and definition.weapon_id == selected_weapon_id:
			valid.append(spell_id)
	equipped_spell_ids = valid


func _rebuild_effect_cache() -> void:
	_permanent_effect_totals.clear()
	for definition in permanent_upgrades:
		var rank := get_permanent_rank(definition.id)
		var current := float(_permanent_effect_totals.get(definition.effect_type, 0.0))
		_permanent_effect_totals[definition.effect_type] = current + definition.value_per_rank * rank


func _evaluate_achievements() -> void:
	for definition in achievements:
		if unlocked_achievements.has(definition.id) or get_stat(definition.statistic_key) < definition.required_value:
			continue
		unlocked_achievements[definition.id] = true
		meta_coins += definition.coin_reward
		achievement_unlocked.emit(definition)


func _get_spell(spell_id: String) -> SpellDefinition:
	for definition in spells:
		if definition.id == spell_id:
			return definition
	return null


func _deduct_coins(amount: int) -> bool:
	if amount < 0 or meta_coins < amount:
		return false
	meta_coins -= amount
	return true


func _serialize() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"meta_coins": meta_coins,
		"permanent_ranks": permanent_ranks,
		"unlocked_characters": unlocked_characters,
		"unlocked_spells": unlocked_spells,
		"unlocked_fusions": unlocked_fusions,
		"collected_relics": collected_relics,
		"unlocked_achievements": unlocked_achievements,
		"statistics": statistics,
		"selected_character_id": selected_character_id,
		"selected_weapon_id": selected_weapon_id,
		"unlocked_weapons": unlocked_weapons,
		"equipped_spell_ids": equipped_spell_ids,
		"upgrade_cap_extensions": upgrade_cap_extensions,
		"player_code": player_code,
	}


func _validate_catalogs() -> void:
	_validate_unique_ids(permanent_upgrades, "permanent upgrade")
	_validate_unique_ids(characters, "character")
	_validate_unique_ids(achievements, "achievement")
	_validate_unique_ids(relics, "relic")
	_validate_unique_ids(spells, "spell")
	_validate_unique_ids(fusion_recipes, "fusion")
	_validate_unique_ids(run_upgrades, "run upgrade")


func _validate_unique_ids(catalog: Array, catalog_name: String) -> void:
	var known: Dictionary = {}
	for resource in catalog:
		var resource_id := String(resource.get("id"))
		if resource_id.is_empty():
			push_error("%s catalog contains an empty ID." % catalog_name.capitalize())
		elif known.has(resource_id):
			push_error("Duplicate %s ID: %s" % [catalog_name, resource_id])
		known[resource_id] = true


func _commit_change() -> void:
	profile_changed.emit()
	if _save_timer != null and _save_timer.is_stopped():
		_save_timer.start()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _save_timer != null and not _save_timer.is_stopped():
		save_profile()
