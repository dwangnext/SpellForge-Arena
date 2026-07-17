extends Node2D

@onready var pause_menu: Control = $Interface/PauseMenu
@onready var hud: Control = $Interface/HUD
@onready var level_up_screen: Control = $Interface/LevelUpScreen
@onready var player: Node2D = $Player
@onready var enemy_spawner: Node2D = $EnemySpawner
@onready var boss_spawner: Node2D = $BossSpawner
@onready var arena_backdrop: Polygon2D = $ArenaBackdrop


func _ready() -> void:
	SettingsManager.settings_changed.connect(queue_redraw)
	var main_menu: Control = $Interface/MainMenu
	set_arena_active(not main_menu.visible)


func set_arena_active(is_active: bool) -> void:
	arena_backdrop.visible = is_active
	player.visible = is_active
	enemy_spawner.visible = is_active
	boss_spawner.visible = is_active
	hud.visible = is_active
	if not is_active:
		pause_menu.hide()
		level_up_screen.hide()
	GameManager.set_paused(not is_active)


func _unhandled_input(event: InputEvent) -> void:
	if hud.visible and event.is_action_pressed("pause_game"):
		pause_menu.toggle()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var grid_color := Color(0.3, 0.35, 0.55, 0.52) if SettingsManager.high_contrast else Color(0.18, 0.21, 0.32, 0.35)
	for x in range(-2400, 2401, 128):
		draw_line(Vector2(x, -2400), Vector2(x, 2400), grid_color, 2.0)
	for y in range(-2400, 2401, 128):
		draw_line(Vector2(-2400, y), Vector2(2400, y), grid_color, 2.0)
