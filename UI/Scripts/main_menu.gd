extends Control

@onready var menu_panel: VBoxContainer = %MenuPanel
@onready var settings_panel: VBoxContainer = %SettingsPanel
@onready var ability_panel: VBoxContainer = %AbilityPanel
@onready var ability_content: VBoxContainer = %AbilityContent
@onready var ability_coins: Label = %AbilityCoins
@onready var ability_weapon_filter: OptionButton = %AbilityWeaponFilter
@onready var fusion_panel: VBoxContainer = %FusionPanel
@onready var fusion_catalog: VBoxContainer = %FusionCatalog
@onready var fusion_slot_top: FusionDropSlot = %FusionSlotTop
@onready var fusion_slot_bottom: FusionDropSlot = %FusionSlotBottom
@onready var fusion_result_name: Label = %FusionResultName
@onready var fusion_result_details: Label = %FusionResultDetails
@onready var fusion_purchase: Button = %FusionPurchase
@onready var fusion_coins: Label = %FusionCoins
@onready var equip_panel: VBoxContainer = %EquipPanel
@onready var equip_content: GridContainer = %EquipContent
@onready var equip_summary: Label = %EquipSummary
@onready var equip_confirm: Button = %EquipConfirm
@onready var redeem_panel: VBoxContainer = %RedeemPanel
@onready var redeem_code: LineEdit = %RedeemCode
@onready var redeem_status: Label = %RedeemStatus
@onready var weapon_panel: VBoxContainer = %WeaponPanel
@onready var weapon_status: Label = %WeaponStatus
@onready var equip_subtitle: Label = %EquipSubtitle
@onready var lobby_panel: VBoxContainer = %LobbyPanel
@onready var lobby_code: Label = %LobbyCode
@onready var lobby_players: VBoxContainer = %LobbyPlayers
@onready var lobby_scaling: Label = %LobbyScaling
@onready var lobby_status: Label = %LobbyStatus
@onready var lobby_start_button: Button = %LobbyStartButton
@onready var home_join_code: LineEdit = %HomeJoinCode
@onready var player_code_label: Label = %PlayerCode

var _selected_fusion_recipe: FusionRecipe
var _pending_equipped_ids: Array[String] = []
var _ability_filter_weapon_id := "wand"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_settings_to_controls()
	MetaProgression.profile_changed.connect(_refresh_ability_shop)
	NetworkManager.lobby_state_changed.connect(_on_lobby_state_changed)
	NetworkManager.connection_status_changed.connect(_on_network_status_changed)
	NetworkManager.game_start_requested.connect(_on_network_game_start_requested)
	fusion_slot_top.spell_dropped.connect(func(_spell): _refresh_fusion_result())
	fusion_slot_bottom.spell_dropped.connect(func(_spell): _refresh_fusion_result())
	if SceneManager.consume_skip_main_menu():
		hide()
		call_deferred("_activate_arena")
	else:
		open()
	player_code_label.text = "YOUR PLAYER CODE: %s" % MetaProgression.player_code
	_populate_ability_weapon_filter()
	_refresh_weapon_labels()


func open() -> void:
	show()
	_show_only(menu_panel)
	modulate.a = 1.0
	var scene = get_tree().current_scene
	if scene != null and scene.is_node_ready() and scene.has_method("set_arena_active"):
		scene.set_arena_active(false)
	else:
		GameManager.set_paused(true)
	%StartButton.grab_focus()


func _on_start_pressed() -> void:
	if NetworkManager.is_in_lobby():
		NetworkManager.leave_lobby()
	_show_only(equip_panel)
	_refresh_equip_screen()


func _on_host_pressed() -> void:
	_show_only(lobby_panel)
	_reset_lobby_display()
	lobby_start_button.visible = true
	lobby_start_button.disabled = true
	NetworkManager.host_lobby()


func _on_join_pressed() -> void:
	_on_join_submitted(home_join_code.text)


func _on_join_submitted(code: String) -> void:
	_show_only(lobby_panel)
	_reset_lobby_display()
	lobby_start_button.visible = false
	NetworkManager.join_lobby(code)


func _on_lobby_start_pressed() -> void:
	lobby_start_button.disabled = true
	lobby_status.text = "Starting the run for everyone…"
	NetworkManager.request_start_game()


func _on_lobby_back_pressed() -> void:
	NetworkManager.leave_lobby()
	_show_only(menu_panel)
	%HostButton.grab_focus()


func _reset_lobby_display() -> void:
	lobby_code.text = "JOIN CODE: ------"
	lobby_scaling.text = "ENEMY HEALTH: 1.50×"
	lobby_status.text = "Connecting…"
	lobby_status.remove_theme_color_override("font_color")
	for child in lobby_players.get_children():
		child.queue_free()


func _on_lobby_state_changed(members: Array, code: String) -> void:
	lobby_code.text = "JOIN CODE: %s" % code
	for child in lobby_players.get_children():
		child.queue_free()
	for member_variant in members:
		var member := member_variant as Dictionary
		var row := Label.new()
		var peer_id := int(member.get("peer_id", 0))
		var role := "HOST" if peer_id == 1 else "TEAMMATE"
		var code_suffix := ""
		if NetworkManager.is_host and GameManager.owner_access_enabled and member.has("player_code"):
			code_suffix = "     PLAYER CODE %s" % String(member.get("player_code", "------"))
		row.text = "●  %s     %s%s" % [String(member.get("name", "Wizard")), role, code_suffix]
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_color_override("font_color", Color("7fffe5") if peer_id == NetworkManager.local_peer_id else Color("b8c9ff"))
		lobby_players.add_child(row)
	var count := maxi(members.size(), 1)
	lobby_scaling.text = "PLAYERS: %d / 3     ENEMY HEALTH: %.2f×" % [count, NetworkManager.get_enemy_health_multiplier()]
	lobby_start_button.visible = NetworkManager.is_host
	lobby_start_button.disabled = not NetworkManager.is_host


func _on_network_status_changed(message: String, is_error: bool) -> void:
	lobby_status.text = message
	lobby_status.add_theme_color_override("font_color", Color("ff6878") if is_error else Color("9fdcff"))


func _on_network_game_start_requested() -> void:
	_show_only(equip_panel)
	_refresh_equip_screen()


func _on_weapon_pressed() -> void:
	_show_only(weapon_panel)
	_refresh_weapon_labels()
	%WandButton.grab_focus()


func _select_weapon(weapon_id: String) -> void:
	if not MetaProgression.is_weapon_unlocked(weapon_id):
		if not MetaProgression.purchase_weapon(weapon_id):
			weapon_status.text = "NEED %s VAULT COINS FOR %s — YOU HAVE %s" % [_format_number(MetaProgression.get_weapon_unlock_cost(weapon_id)), MetaProgression.get_weapon_display_name(weapon_id).to_upper(), _format_number(MetaProgression.meta_coins)]
			weapon_status.add_theme_color_override("font_color", Color("ff6878"))
			return
	if MetaProgression.select_weapon(weapon_id):
		_refresh_weapon_labels()


func _refresh_weapon_labels() -> void:
	var selected := MetaProgression.selected_weapon_id
	%WeaponButton.text = "CHANGE WEAPON — %s  %s" % [MetaProgression.get_weapon_display_name(selected).to_upper(), MetaProgression.get_weapon_power_circles(selected)]
	var buttons := {"wand": %WandButton, "revolver": %RevolverButton, "gauntlet": %GauntletButton}
	for weapon_id in MetaProgression.WEAPON_IDS:
		var button := buttons[weapon_id] as Button
		var unlocked := MetaProgression.is_weapon_unlocked(weapon_id)
		var state := "EQUIPPED" if selected == weapon_id else ("UNLOCKED" if unlocked else "LOCKED — %s COINS" % _format_number(MetaProgression.get_weapon_unlock_cost(weapon_id)))
		button.text = "%s    %s\n%s\n%s" % [MetaProgression.get_weapon_display_name(weapon_id).to_upper(), MetaProgression.get_weapon_power_circles(weapon_id), MetaProgression.get_weapon_description(weapon_id), state]
	weapon_status.text = "EQUIPPED: %s     POWER %s     VAULT COINS: %s" % [MetaProgression.get_weapon_display_name(selected).to_upper(), MetaProgression.get_weapon_power_circles(selected), _format_number(MetaProgression.meta_coins)]
	weapon_status.add_theme_color_override("font_color", Color("ffd447") if selected == "revolver" else (Color("e46cff") if selected == "gauntlet" else Color("9fdcff")))


func _on_weapon_back_pressed() -> void:
	_show_only(menu_panel)
	%WeaponButton.grab_focus()


func _begin_start() -> void:
	_apply_controls_to_settings()
	if SettingsManager.reduced_motion:
		_finish_start()
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 0.0, 0.32)
	tween.tween_callback(_finish_start)


func _finish_start() -> void:
	hide()
	_activate_arena()


func _activate_arena() -> void:
	var scene = get_tree().current_scene
	if scene != null and scene.has_method("set_arena_active"):
		scene.set_arena_active(true)
	else:
		GameManager.set_paused(false)


func _on_settings_pressed() -> void:
	_show_only(settings_panel)
	_settings_to_controls()
	%MasterSlider.grab_focus()


func _on_settings_back_pressed() -> void:
	_apply_controls_to_settings()
	_show_only(menu_panel)
	%SettingsButton.grab_focus()


func _on_abilities_pressed() -> void:
	_show_only(ability_panel)
	_ability_filter_weapon_id = MetaProgression.selected_weapon_id
	_select_filter_item(_ability_filter_weapon_id)
	_refresh_ability_shop()


func _on_abilities_back_pressed() -> void:
	_show_only(menu_panel)
	%AbilitiesButton.grab_focus()


func _on_fusions_pressed() -> void:
	_show_only(fusion_panel)
	_refresh_fusion_catalog()
	_refresh_fusion_result()


func _on_fusions_back_pressed() -> void:
	_show_only(menu_panel)
	%FusionsButton.grab_focus()


func _show_only(active_panel: Control) -> void:
	for panel in [menu_panel, settings_panel, ability_panel, fusion_panel, equip_panel, redeem_panel, weapon_panel, lobby_panel]:
		panel.visible = panel == active_panel


func _on_redeem_pressed() -> void:
	_show_only(redeem_panel)
	redeem_code.clear()
	redeem_status.text = "Enter a code to unlock its reward."
	redeem_status.remove_theme_color_override("font_color")
	redeem_code.grab_focus()


func _on_redeem_submit_pressed(_submitted_text := "") -> void:
	var entered := redeem_code.text.strip_edges()
	if entered == "609618":
		GameManager.enable_owner_access()
		MetaProgression.unlock_everything()
		NetworkManager.request_lobby_refresh()
		_refresh_weapon_labels()
		_refresh_ability_shop()
		redeem_status.text = "OWNER ACCESS ENABLED — full arsenal unlocked. Hosts can view teammate player codes."
		redeem_status.add_theme_color_override("font_color", Color("ffd447"))
	elif entered == "6767":
		GameManager.enable_cheats()
		redeem_status.text = "CHEAT BAR UNLOCKED — available inside the arena."
		redeem_status.add_theme_color_override("font_color", Color("ffd447"))
	else:
		redeem_status.text = "Invalid code."
		redeem_status.add_theme_color_override("font_color", Color("ff5d72"))
	redeem_code.clear()


func _on_redeem_back_pressed() -> void:
	_show_only(menu_panel)
	%RedeemButton.grab_focus()


func _refresh_equip_screen() -> void:
	var available := MetaProgression.get_available_equippable_spells()
	var weapon_name := MetaProgression.get_weapon_display_name(MetaProgression.selected_weapon_id)
	var rating := MetaProgression.get_weapon_power_circles(MetaProgression.selected_weapon_id)
	equip_subtitle.text = "Choose six %s abilities. Click again to unequip.  POWER %s" % [weapon_name, rating]
	_pending_equipped_ids.clear()
	for child in equip_content.get_children():
		equip_content.remove_child(child)
		child.queue_free()
	for spell in available:
		var button := Button.new()
		button.custom_minimum_size = Vector2(250, 72)
		button.toggle_mode = true
		button.button_pressed = false
		button.text = "%s%s\n%s  %s" % [spell.display_name, " — FUSION" if MetaProgression.is_fusion_spell_id(spell.id) else "", weapon_name.to_upper(), rating]
		button.set_meta("spell_id", spell.id)
		button.tooltip_text = spell.description
		button.add_theme_color_override("font_color", spell.primary_color.lightened(0.2))
		_apply_equip_button_styles(button)
		button.toggled.connect(_toggle_equipped_spell.bind(spell.id, button))
		equip_content.add_child(button)
	_refresh_equip_summary()


func _toggle_equipped_spell(enabled: bool, spell_id: String, button: Button) -> void:
	if enabled:
		if _pending_equipped_ids.size() >= 6:
			button.set_pressed_no_signal(false)
			return
		_pending_equipped_ids.append(spell_id)
	else:
		_pending_equipped_ids.erase(spell_id)
	_refresh_equip_button_states()
	_refresh_equip_summary()


func _apply_equip_button_styles(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("090a14")
	normal.border_color = Color(0.22, 0.25, 0.4, 0.65)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(5)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("151429")
	hover.border_color = Color(0.42, 0.48, 0.72, 0.9)
	var selected := normal.duplicate() as StyleBoxFlat
	selected.bg_color = Color(0.25, 0.19, 0.035, 0.96)
	selected.border_color = Color("ffd447")
	selected.set_border_width_all(4)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", selected)
	button.add_theme_stylebox_override("hover_pressed", selected)


func _refresh_equip_button_states() -> void:
	for child in equip_content.get_children():
		var button := child as Button
		if button != null:
			button.set_pressed_no_signal(_pending_equipped_ids.has(String(button.get_meta("spell_id", ""))))


func _refresh_equip_summary() -> void:
	var required := mini(6, MetaProgression.get_available_equippable_spells().size())
	equip_summary.text = "EQUIPPED %d / %d     KEYS 1–6" % [_pending_equipped_ids.size(), required]
	equip_confirm.disabled = _pending_equipped_ids.size() != required or required == 0


func _on_equip_confirm_pressed() -> void:
	if MetaProgression.set_equipped_spells(_pending_equipped_ids):
		var scene = get_tree().current_scene
		if scene != null:
			var caster := scene.get_node_or_null("Player/SpellCaster") as SpellCaster
			if caster != null:
				caster.reload_equipped_loadout()
		_begin_start()


func _on_equip_back_pressed() -> void:
	if NetworkManager.is_in_lobby():
		_show_only(lobby_panel)
		lobby_start_button.grab_focus()
	else:
		_show_only(menu_panel)
		%StartButton.grab_focus()


func _refresh_fusion_catalog() -> void:
	fusion_coins.text = "VAULT COINS: %d" % MetaProgression.meta_coins
	for child in fusion_catalog.get_children():
		fusion_catalog.remove_child(child)
		child.queue_free()
	for spell in MetaProgression.spells:
		if not spell.fusion_eligible or not MetaProgression.is_spell_unlocked(spell.id):
			continue
		var card := FusionSpellCard.new()
		card.configure(spell)
		card.pressed.connect(_quick_place_fusion_spell.bind(spell))
		fusion_catalog.add_child(card)


func _quick_place_fusion_spell(spell: SpellDefinition) -> void:
	if fusion_slot_top.spell == null:
		fusion_slot_top.set_spell(spell)
	else:
		fusion_slot_bottom.set_spell(spell)
	_refresh_fusion_result()


func _refresh_fusion_result() -> void:
	_selected_fusion_recipe = _find_fusion_recipe(fusion_slot_top.spell, fusion_slot_bottom.spell)
	if _selected_fusion_recipe == null:
		fusion_result_name.text = "UNKNOWN FUSION"
		fusion_result_details.text = "Drag two compatible spells into the upper and lower forge slots."
		fusion_purchase.text = "NO RECIPE"
		fusion_purchase.disabled = true
		return
	var result := _selected_fusion_recipe.output_spell
	var cost := MetaProgression.get_fusion_cost(_selected_fusion_recipe)
	var owned := MetaProgression.is_fusion_unlocked(_selected_fusion_recipe.id)
	var ingredients_owned := MetaProgression.is_spell_unlocked(fusion_slot_top.spell.id) and MetaProgression.is_spell_unlocked(fusion_slot_bottom.spell.id)
	fusion_result_name.text = result.display_name.to_upper()
	fusion_result_name.add_theme_color_override("font_color", result.primary_color.lightened(0.2))
	var effective_power := result.damage * MetaProgression.get_fusion_damage_multiplier(result.id)
	fusion_result_details.text = "%s\n\nFusion power: %.0f   Cooldown: %.2fs\nStronger than either ingredient, but more focused than both together." % [result.description, effective_power, result.cooldown]
	fusion_purchase.text = "OWNED" if owned else ("OWN BOTH INGREDIENTS" if not ingredients_owned else "FORGE FOR %d COINS" % cost)
	fusion_purchase.disabled = owned or not ingredients_owned or MetaProgression.meta_coins < cost


func _find_fusion_recipe(first: SpellDefinition, second: SpellDefinition) -> FusionRecipe:
	if first == null or second == null or first.id == second.id:
		return null
	for recipe in MetaProgression.fusion_recipes:
		if recipe.component_spell_ids.size() == 2 and recipe.component_spell_ids.has(first.id) and recipe.component_spell_ids.has(second.id):
			return recipe
	return null


func _on_fusion_purchase_pressed() -> void:
	if MetaProgression.purchase_fusion(_selected_fusion_recipe):
		_refresh_fusion_catalog()
		_refresh_fusion_result()


func _refresh_ability_shop() -> void:
	if ability_content == null:
		return
	ability_coins.text = "VAULT COINS: %d" % MetaProgression.meta_coins
	for child in ability_content.get_children():
		ability_content.remove_child(child)
		child.queue_free()
	var ability_header := Label.new()
	var weapon_name := MetaProgression.get_weapon_display_name(_ability_filter_weapon_id)
	var rating := MetaProgression.get_weapon_power_circles(_ability_filter_weapon_id)
	ability_header.text = "%s ABILITIES     POWER %s" % [weapon_name.to_upper(), rating]
	ability_header.add_theme_font_size_override("font_size", 20)
	ability_content.add_child(ability_header)
	for spell in MetaProgression.spells:
		if spell.weapon_id != _ability_filter_weapon_id:
			continue
		var owned := MetaProgression.is_spell_unlocked(spell.id)
		var weapon_locked := not MetaProgression.is_weapon_unlocked(spell.weapon_id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 56)
		button.custom_minimum_size = Vector2(0, 70)
		button.text = "%s  —  %s\n%s  %s" % [spell.display_name, "OWNED" if owned else ("UNLOCK %s FIRST" % weapon_name.to_upper() if weapon_locked else "%s coins" % _format_number(spell.unlock_cost)), weapon_name.to_upper(), rating]
		button.tooltip_text = spell.description
		button.disabled = owned or weapon_locked or MetaProgression.meta_coins < spell.unlock_cost
		button.pressed.connect(_purchase_ability.bind(spell))
		ability_content.add_child(button)
	var cap_header := Label.new()
	cap_header.text = "UPGRADE CAP EXPANSIONS"
	cap_header.add_theme_font_size_override("font_size", 20)
	cap_header.add_theme_color_override("font_color", Color("ffd447"))
	ability_content.add_child(cap_header)
	var cap_hint := Label.new()
	cap_hint.text = "Permanently add one more available rank to any run upgrade. Each cap can be expanded three times."
	cap_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ability_content.add_child(cap_hint)
	for upgrade in MetaProgression.run_upgrades:
		var extension := MetaProgression.get_upgrade_cap_extension(upgrade)
		var cost := MetaProgression.get_upgrade_cap_cost(upgrade)
		var cap_button := Button.new()
		cap_button.custom_minimum_size = Vector2(0, 56)
		cap_button.text = "%s  —  Cap %d  —  %s" % [upgrade.display_name, MetaProgression.get_upgrade_cap(upgrade), "MAX EXPANSION" if extension >= MetaProgression.MAX_UPGRADE_CAP_EXTENSIONS else "+1 rank for %d coins" % cost]
		cap_button.tooltip_text = upgrade.format_description()
		cap_button.disabled = extension >= MetaProgression.MAX_UPGRADE_CAP_EXTENSIONS or MetaProgression.meta_coins < cost
		cap_button.pressed.connect(_purchase_upgrade_cap.bind(upgrade))
		ability_content.add_child(cap_button)


func _populate_ability_weapon_filter() -> void:
	ability_weapon_filter.clear()
	for weapon_id in MetaProgression.WEAPON_IDS:
		ability_weapon_filter.add_item("%s    %s" % [MetaProgression.get_weapon_display_name(weapon_id).to_upper(), MetaProgression.get_weapon_power_circles(weapon_id)])
		ability_weapon_filter.set_item_metadata(ability_weapon_filter.item_count - 1, weapon_id)
	_select_filter_item(MetaProgression.selected_weapon_id)


func _select_filter_item(weapon_id: String) -> void:
	for index in ability_weapon_filter.item_count:
		if String(ability_weapon_filter.get_item_metadata(index)) == weapon_id:
			ability_weapon_filter.select(index)
			return


func _on_ability_weapon_selected(index: int) -> void:
	_ability_filter_weapon_id = String(ability_weapon_filter.get_item_metadata(index))
	_refresh_ability_shop()


func _format_number(value: int) -> String:
	var text_value := str(absi(value))
	var parts: Array[String] = []
	while text_value.length() > 3:
		parts.push_front(text_value.right(3))
		text_value = text_value.left(text_value.length() - 3)
	parts.push_front(text_value)
	return ",".join(parts)


func _purchase_ability(spell: SpellDefinition) -> void:
	MetaProgression.unlock_spell(spell.id)
	_refresh_ability_shop()


func _purchase_upgrade_cap(upgrade: UpgradeDefinition) -> void:
	MetaProgression.purchase_upgrade_cap(upgrade)
	_refresh_ability_shop()


func _on_quit_pressed() -> void:
	SceneManager.quit_game()


func _settings_to_controls() -> void:
	%MasterSlider.value = SettingsManager.master_volume * 100.0
	%MusicSlider.value = SettingsManager.music_volume * 100.0
	%SFXSlider.value = SettingsManager.sfx_volume * 100.0
	%ShakeSlider.value = SettingsManager.screen_shake_intensity * 100.0
	%FlashSlider.value = SettingsManager.flash_intensity * 100.0
	%ReducedMotion.button_pressed = SettingsManager.reduced_motion
	%HighContrast.button_pressed = SettingsManager.high_contrast


func _apply_controls_to_settings() -> void:
	SettingsManager.master_volume = %MasterSlider.value / 100.0
	SettingsManager.music_volume = %MusicSlider.value / 100.0
	SettingsManager.sfx_volume = %SFXSlider.value / 100.0
	SettingsManager.screen_shake_intensity = %ShakeSlider.value / 100.0
	SettingsManager.flash_intensity = %FlashSlider.value / 100.0
	SettingsManager.reduced_motion = %ReducedMotion.button_pressed
	SettingsManager.high_contrast = %HighContrast.button_pressed
	SettingsManager.save_settings()
