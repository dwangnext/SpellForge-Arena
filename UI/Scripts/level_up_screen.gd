extends Control

@onready var choice_row: GridContainer = %ChoiceRow
@onready var title: Label = %Title
@onready var points_label: Label = %PointsLabel

var _upgrade_controller: UpgradeController
var _pending_levelups := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	GameManager.player_registered.connect(_bind_player)
	if is_instance_valid(GameManager.player):
		_bind_player(GameManager.player)


func _bind_player(player: Node) -> void:
	_upgrade_controller = player.get_node_or_null("UpgradeController") as UpgradeController
	var progression := player.get_node_or_null("LevelProgression") as LevelProgression
	if progression != null and not progression.level_gained.is_connected(_on_level_gained):
		progression.level_gained.connect(_on_level_gained)


func _on_level_gained(level: int) -> void:
	_pending_levelups += 1
	title.text = "LEVEL %d — UPGRADE ARMORY" % level
	if not visible:
		_show_choices()


func grant_upgrade_points(amount: int) -> void:
	if amount <= 0:
		return
	_pending_levelups += amount
	title.text = "CHEAT ARMORY — SPEND UPGRADE POINTS"
	_show_choices()


func _show_choices() -> void:
	if _upgrade_controller == null:
		return
	for child in choice_row.get_children():
		choice_row.remove_child(child)
		child.queue_free()
	var choices := _upgrade_controller.get_available_upgrades()
	if choices.is_empty():
		_pending_levelups = 0
		_finish_selection()
		return
	points_label.text = "UPGRADE POINTS: %d     Spend one point on any available upgrade" % _pending_levelups
	for upgrade in choices:
		var button := _create_choice(upgrade)
		choice_row.add_child(button)
		if not SettingsManager.reduced_motion:
			button.modulate.a = 0.0
			button.scale = Vector2(0.92, 0.92)
			button.pivot_offset = button.size * 0.5
			var tween := create_tween()
			tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tween.set_parallel(true)
			tween.tween_property(button, "modulate:a", 1.0, 0.2)
			tween.tween_property(button, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show()
	GameManager.set_local_modal(&"level_up", true)
	GameManager.set_paused(true)
	var first_choice := choice_row.get_child(0) as Button
	if first_choice != null:
		first_choice.grab_focus()


func _create_choice(upgrade: UpgradeDefinition) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(270, 150)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var stacks := _upgrade_controller.get_stack_count(upgrade)
	var cap := MetaProgression.get_upgrade_cap(upgrade)
	button.text = "%s\n\n%s\n\nRank %d → %d / %d" % [upgrade.display_name, upgrade.format_description(), stacks, stacks + 1, cap]
	button.add_theme_color_override("font_color", upgrade.accent_color.lightened(0.2))
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(_select_upgrade.bind(upgrade))
	return button


func _select_upgrade(upgrade: UpgradeDefinition) -> void:
	_upgrade_controller.apply_upgrade(upgrade)
	_pending_levelups = maxi(_pending_levelups - 1, 0)
	if _pending_levelups > 0:
		_show_choices()
	else:
		_finish_selection()


func _finish_selection() -> void:
	hide()
	GameManager.set_local_modal(&"level_up", false)
	GameManager.set_paused(false)
