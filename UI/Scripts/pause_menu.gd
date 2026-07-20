extends Control

@onready var main_panel: VBoxContainer = %MainPanel
@onready var settings_panel: VBoxContainer = %SettingsPanel
@onready var progression_panel: VBoxContainer = %ProgressionPanel
@onready var progression_content: VBoxContainer = %ProgressionContent
@onready var progression_summary: Label = %ProgressionSummary
var _syncing_settings := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	settings_panel.hide()
	progression_panel.hide()
	MetaProgression.profile_changed.connect(_refresh_progression)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause_game"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	main_panel.show()
	settings_panel.hide()
	progression_panel.hide()
	show()
	GameManager.set_local_modal(&"pause_menu", true)
	GameManager.set_paused(true)
	if not SettingsManager.reduced_motion:
		$Panel.pivot_offset = $Panel.size * 0.5
		$Panel.scale = Vector2(0.94, 0.94)
		$Panel.modulate.a = 0.0
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_parallel(true)
		tween.tween_property($Panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property($Panel, "modulate:a", 1.0, 0.14)
	%ResumeButton.grab_focus()


func close() -> void:
	hide()
	GameManager.set_local_modal(&"pause_menu", false)
	GameManager.set_paused(false)


func _on_resume_pressed() -> void:
	close()


func _on_settings_pressed() -> void:
	main_panel.hide()
	settings_panel.show()
	_syncing_settings = true
	%VolumeSlider.value = SettingsManager.master_volume * 100.0
	%MusicVolumeSlider.value = SettingsManager.music_volume * 100.0
	%SFXVolumeSlider.value = SettingsManager.sfx_volume * 100.0
	%ShakeSlider.value = SettingsManager.screen_shake_intensity * 100.0
	%FlashSlider.value = SettingsManager.flash_intensity * 100.0
	%ReducedMotion.button_pressed = SettingsManager.reduced_motion
	%HighContrast.button_pressed = SettingsManager.high_contrast
	_syncing_settings = false
	%VolumeSlider.grab_focus()


func _on_progression_pressed() -> void:
	main_panel.hide()
	settings_panel.hide()
	progression_panel.show()
	_refresh_progression()


func _on_settings_back_pressed() -> void:
	settings_panel.hide()
	main_panel.show()
	%SettingsButton.grab_focus()


func _on_progression_back_pressed() -> void:
	progression_panel.hide()
	main_panel.show()
	%ProgressionButton.grab_focus()


func _on_setting_changed(_value = null) -> void:
	if _syncing_settings:
		return
	SettingsManager.master_volume = %VolumeSlider.value / 100.0
	SettingsManager.music_volume = %MusicVolumeSlider.value / 100.0
	SettingsManager.sfx_volume = %SFXVolumeSlider.value / 100.0
	SettingsManager.screen_shake_intensity = %ShakeSlider.value / 100.0
	SettingsManager.flash_intensity = %FlashSlider.value / 100.0
	SettingsManager.reduced_motion = %ReducedMotion.button_pressed
	SettingsManager.high_contrast = %HighContrast.button_pressed
	SettingsManager.save_settings()


func _on_quit_pressed() -> void:
	SceneManager.quit_game()


func _refresh_progression() -> void:
	if progression_content == null:
		return
	for child in progression_content.get_children():
		progression_content.remove_child(child)
		child.queue_free()
	var character := MetaProgression.get_selected_character()
	var character_name := character.display_name if character != null else "None"
	progression_summary.text = "VAULT COINS: %d     ACTIVE: %s\nSPELLS: %d/%d     RELICS: %d/%d     ACHIEVEMENTS: %d/%d" % [
		MetaProgression.meta_coins,
		character_name,
		MetaProgression.unlocked_spells.size(), MetaProgression.spells.size(),
		MetaProgression.collected_relics.size(), MetaProgression.relics.size(),
		MetaProgression.unlocked_achievements.size(), MetaProgression.achievements.size(),
	]
	_add_section("PERMANENT UPGRADES")
	for upgrade in MetaProgression.permanent_upgrades:
		var rank := MetaProgression.get_permanent_rank(upgrade.id)
		var button := Button.new()
		button.text = "%s  %d/%d  —  %s" % [upgrade.display_name, rank, upgrade.maximum_rank, "MAX" if rank >= upgrade.maximum_rank else "%d coins" % upgrade.cost_for_rank(rank)]
		button.disabled = rank >= upgrade.maximum_rank
		button.pressed.connect(_purchase_upgrade.bind(upgrade))
		progression_content.add_child(button)
	_add_section("ABILITY SHOP")
	var locked_spell_count := 0
	for spell in MetaProgression.spells:
		if MetaProgression.is_spell_unlocked(spell.id):
			continue
		locked_spell_count += 1
		var button := Button.new()
		button.text = "%s — Unlock: %d coins" % [spell.display_name, spell.unlock_cost]
		button.tooltip_text = spell.description
		button.pressed.connect(_unlock_spell.bind(spell))
		progression_content.add_child(button)
	if locked_spell_count == 0:
		var complete_label := Label.new()
		complete_label.text = "All discovered spells are unlocked."
		progression_content.add_child(complete_label)
	_add_section("COLLECTION & STATISTICS")
	var collection := Label.new()
	collection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	collection.text = "Relics: %s\nAchievements: %s\nLifetime enemies: %d   Bosses: %d   Fusions: %d   Highest level: %d\nRuns: %d   Spells cast: %d   Damage dealt: %d   Playtime: %s" % [
		_join_collected_relics(),
		_join_achievements(),
		MetaProgression.get_stat("enemies_defeated"),
		MetaProgression.get_stat("bosses_defeated"),
		MetaProgression.get_stat("fusions_activated"),
		MetaProgression.get_stat("highest_level"),
		MetaProgression.get_stat("runs_started"),
		MetaProgression.get_stat("spells_cast"),
		MetaProgression.get_stat("damage_dealt"),
		_format_playtime(MetaProgression.get_stat("play_time_seconds")),
	]
	progression_content.add_child(collection)


func _add_section(title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 20)
	progression_content.add_child(label)


func _purchase_upgrade(definition: PermanentUpgradeDefinition) -> void:
	MetaProgression.purchase_permanent_upgrade(definition)
	_refresh_progression()


func _unlock_spell(definition: SpellDefinition) -> void:
	MetaProgression.unlock_spell(definition.id)
	_refresh_progression()


func _join_collected_relics() -> String:
	var names := PackedStringArray()
	for relic in MetaProgression.relics:
		if MetaProgression.collected_relics.has(relic.id):
			names.append(relic.display_name)
	return ", ".join(names) if not names.is_empty() else "None yet"


func _join_achievements() -> String:
	var names := PackedStringArray()
	for achievement in MetaProgression.achievements:
		if MetaProgression.unlocked_achievements.has(achievement.id):
			names.append(achievement.display_name)
	return ", ".join(names) if not names.is_empty() else "None yet"


func _format_playtime(total_seconds: int) -> String:
	return "%dh %02dm %02ds" % [total_seconds / 3600, (total_seconds / 60) % 60, total_seconds % 60]
