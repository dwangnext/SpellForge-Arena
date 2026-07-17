extends Control

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var dash_bar: ProgressBar = %DashBar
@onready var death_panel: PanelContainer = %DeathPanel
@onready var experience_label: Label = %ExperienceLabel
@onready var coin_label: Label = %CoinLabel
@onready var spell_bar: HBoxContainer = %SpellBar
@onready var level_label: Label = %LevelLabel
@onready var experience_bar: ProgressBar = %ExperienceBar
@onready var fusion_label: Label = %FusionLabel
@onready var boss_panel: PanelContainer = %BossPanel
@onready var boss_name_label: Label = %BossNameLabel
@onready var boss_phase_label: Label = %BossPhaseLabel
@onready var boss_health_bar: ProgressBar = %BossHealthBar
@onready var boss_health_label: Label = %BossHealthLabel
@onready var reward_notice: Label = %RewardNotice
@onready var screen_flash: ColorRect = %ScreenFlash
@onready var contrast_overlay: ColorRect = %ContrastOverlay
@onready var control_hint: Label = %Hint
@onready var cheat_bar: PanelContainer = %CheatBar
@onready var cheat_status: Label = %CheatStatus

var _spell_labels: Array[Label] = []
var _spell_names: Array[String] = []
var _selected_spell_index := 0
var _fusion_display_remaining := 0.0
var _reward_display_remaining := 0.0
var _flash_remaining := 0.0
var _flash_duration := 0.0
var _flash_strength := 0.0
var _last_controller_mode := false


func _process(delta: float) -> void:
	var controller_mode := InputManager.is_using_controller()
	if controller_mode != _last_controller_mode:
		_last_controller_mode = controller_mode
		_update_control_hint()
	if _fusion_display_remaining > 0.0:
		_fusion_display_remaining = maxf(_fusion_display_remaining - delta, 0.0)
		fusion_label.modulate.a = minf(_fusion_display_remaining * 2.0, 1.0)
		if _fusion_display_remaining <= 0.0:
			fusion_label.hide()
	if _reward_display_remaining > 0.0:
		_reward_display_remaining = maxf(_reward_display_remaining - delta, 0.0)
		reward_notice.modulate.a = minf(_reward_display_remaining * 2.0, 1.0)
		if _reward_display_remaining <= 0.0:
			reward_notice.hide()
	if _flash_remaining > 0.0:
		_flash_remaining = maxf(_flash_remaining - delta, 0.0)
		screen_flash.modulate.a = _flash_strength * (_flash_remaining / maxf(_flash_duration, 0.001))
		if _flash_remaining <= 0.0:
			screen_flash.hide()


func _ready() -> void:
	GameManager.player_registered.connect(_bind_player)
	GameManager.player_died.connect(_show_death_panel)
	GameManager.rewards_changed.connect(_update_rewards)
	GameManager.boss_registered.connect(_show_boss)
	GameManager.boss_health_changed.connect(_update_boss_health)
	GameManager.boss_phase_changed.connect(_update_boss_phase)
	GameManager.boss_defeated.connect(_hide_boss)
	GameManager.boss_reward_collected.connect(_show_reward_notice)
	GameManager.cheats_enabled_changed.connect(_set_cheat_bar_enabled)
	CameraEffects.flash_requested.connect(_show_screen_flash)
	SettingsManager.settings_changed.connect(_apply_accessibility)
	_apply_accessibility()
	_update_control_hint()
	_update_rewards(GameManager.experience, GameManager.coins)
	_set_cheat_bar_enabled(GameManager.cheats_enabled)
	if is_instance_valid(GameManager.player):
		_bind_player(GameManager.player)


func _bind_player(player: Node) -> void:
	var health_component: HealthComponent = player.get_node("HealthComponent")
	if not health_component.health_changed.is_connected(_update_health):
		health_component.health_changed.connect(_update_health)
	if not player.dash_cooldown_changed.is_connected(_update_dash):
		player.dash_cooldown_changed.connect(_update_dash)
	_update_health(health_component.current_health, health_component.maximum_health)
	_update_dash(0.0, player.dash_cooldown)
	var caster := player.get_node_or_null("SpellCaster") as SpellCaster
	if caster != null:
		if not caster.loadout_ready.is_connected(_build_spell_bar):
			caster.loadout_ready.connect(_build_spell_bar)
		if not caster.selection_changed.is_connected(_select_spell):
			caster.selection_changed.connect(_select_spell)
		if not caster.cooldown_changed.is_connected(_update_spell_cooldown):
			caster.cooldown_changed.connect(_update_spell_cooldown)
		_build_spell_bar(caster.loadout)
		if not caster.loadout.is_empty():
			_select_spell(caster.selected_index, caster.loadout[caster.selected_index] as SpellDefinition)
	var progression := player.get_node_or_null("LevelProgression") as LevelProgression
	if progression != null:
		if not progression.progress_changed.is_connected(_update_level_progress):
			progression.progress_changed.connect(_update_level_progress)
		_update_level_progress(progression.level, progression.current_xp, progression.required_xp())
	var fusion_controller := player.get_node_or_null("FusionController") as FusionController
	if fusion_controller != null and not fusion_controller.fusion_activated.is_connected(_show_fusion):
		fusion_controller.fusion_activated.connect(_show_fusion)


func _update_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [roundi(current), roundi(maximum)]


func _update_dash(remaining: float, duration: float) -> void:
	dash_bar.max_value = duration
	dash_bar.value = duration - remaining


func _show_death_panel() -> void:
	death_panel.show()


func _update_rewards(experience: int, coins: int) -> void:
	experience_label.text = "GEMS  %d" % experience
	coin_label.text = "COINS  %d" % coins


func _build_spell_bar(definitions: Array[Resource]) -> void:
	for child in spell_bar.get_children():
		spell_bar.remove_child(child)
		child.queue_free()
	_spell_labels.clear()
	_spell_names.clear()
	_spell_labels.resize(definitions.size())
	_spell_names.resize(definitions.size())
	for index in range(definitions.size()):
		var definition := definitions[index] as SpellDefinition
		if definition == null:
			continue
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(138, 52)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text = "[%s] %s" % [_spell_slot_label(index), definition.display_name]
		label.add_theme_color_override("font_color", definition.primary_color.lightened(0.2))
		panel.add_child(label)
		spell_bar.add_child(panel)
		_spell_labels[index] = label
		_spell_names[index] = definition.display_name
	_refresh_spell_selection()


func _select_spell(index: int, _definition: SpellDefinition) -> void:
	_selected_spell_index = index
	_refresh_spell_selection()


func _update_spell_cooldown(index: int, remaining: float, _duration: float) -> void:
	if index < 0 or index >= _spell_labels.size() or _spell_labels[index] == null:
		return
	_spell_labels[index].text = "[%s] %s%s" % [_spell_slot_label(index), _spell_names[index], "\n%.1fs" % remaining if remaining > 0.0 else ""]


func _spell_slot_label(index: int) -> String:
	return str(index + 1)


func _refresh_spell_selection() -> void:
	for index in range(_spell_labels.size()):
		if _spell_labels[index] != null:
			_spell_labels[index].add_theme_font_size_override("font_size", 16 if index == _selected_spell_index else 13)


func _update_level_progress(level: int, current_xp: int, required_xp: int) -> void:
	level_label.text = "LEVEL %d" % level
	experience_bar.max_value = required_xp
	experience_bar.value = current_xp


func _show_fusion(recipe: FusionRecipe) -> void:
	fusion_label.text = "SPELL FUSION\n%s" % recipe.display_name
	fusion_label.add_theme_color_override("font_color", recipe.output_spell.primary_color.lightened(0.2))
	fusion_label.modulate.a = 1.0
	fusion_label.show()
	_fusion_display_remaining = 2.0


func _show_boss(_boss: Node2D, definition: BossDefinition) -> void:
	boss_name_label.text = "%s — %s" % [definition.display_name, definition.subtitle]
	boss_name_label.add_theme_color_override("font_color", definition.primary_color.lightened(0.25))
	boss_health_bar.max_value = definition.maximum_health
	boss_health_bar.value = definition.maximum_health
	boss_health_label.text = "%d / %d" % [roundi(definition.maximum_health), roundi(definition.maximum_health)]
	_update_boss_phase(1)
	boss_panel.show()


func _update_boss_health(current: float, maximum: float) -> void:
	boss_health_bar.max_value = maximum
	boss_health_bar.value = current
	boss_health_label.text = "%d / %d" % [roundi(current), roundi(maximum)]


func _update_boss_phase(phase: int) -> void:
	boss_phase_label.text = "PHASE %d" % phase


func _hide_boss(_definition: BossDefinition) -> void:
	boss_panel.hide()


func _show_reward_notice(_reward_id: String, reward_name: String) -> void:
	reward_notice.text = "BOSS RELIC ACQUIRED\n%s" % reward_name
	reward_notice.modulate.a = 1.0
	reward_notice.show()
	_reward_display_remaining = 3.0


func _show_screen_flash(color: Color, strength: float, duration: float) -> void:
	screen_flash.color = color
	screen_flash.modulate.a = strength
	screen_flash.show()
	_flash_strength = strength
	_flash_duration = maxf(duration, 0.01)
	_flash_remaining = _flash_duration


func _apply_accessibility() -> void:
	contrast_overlay.visible = SettingsManager.high_contrast


func _update_control_hint() -> void:
	if _last_controller_mode:
		control_hint.text = "LEFT STICK MOVE   RIGHT STICK AIM   X/RB ATTACK   B/LB CAST   D-PAD CYCLE   A DASH   START PAUSE"
	else:
		control_hint.text = "WASD / ARROWS MOVE   LEFT CLICK FIRE   HOLD RIGHT CLICK MOVE   SPACE DASH   1–6 SELECT"


func _on_restart_pressed() -> void:
	SceneManager.restart_run()


func _on_menu_pressed() -> void:
	SceneManager.reload_current_scene()


func _set_cheat_bar_enabled(enabled: bool) -> void:
	cheat_bar.visible = enabled


func _on_cheat_coins_pressed() -> void:
	MetaProgression.grant_coins(1000)
	cheat_status.text = "+1,000 vault coins added"


func _on_cheat_points_pressed() -> void:
	var level_up_screen := get_tree().current_scene.get_node_or_null("Interface/LevelUpScreen")
	if level_up_screen == null or not level_up_screen.has_method("grant_upgrade_points"):
		cheat_status.text = "Upgrade Armory unavailable"
		return
	level_up_screen.grant_upgrade_points(10)
	cheat_status.text = "+10 upgrade points added"
