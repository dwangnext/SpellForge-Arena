extends Node2D

@onready var pause_menu: Control = $Interface/PauseMenu
@onready var hud: Control = $Interface/HUD
@onready var level_up_screen: Control = $Interface/LevelUpScreen
@onready var player: Node2D = $Player
@onready var enemy_spawner: Node2D = $EnemySpawner
@onready var boss_spawner: Node2D = $BossSpawner
@onready var arena_backdrop: Polygon2D = $ArenaBackdrop

var _network_spawn_initialized := false


func _ready() -> void:
	SettingsManager.settings_changed.connect(queue_redraw)
	var main_menu: Control = $Interface/MainMenu
	set_arena_active(not main_menu.visible)


func set_arena_active(is_active: bool) -> void:
	var controls_world := is_active and NetworkManager.is_world_authority()
	arena_backdrop.visible = is_active
	player.visible = is_active
	enemy_spawner.visible = is_active
	boss_spawner.visible = is_active
	enemy_spawner.set_physics_process(controls_world)
	boss_spawner.set_physics_process(controls_world)
	hud.visible = is_active
	if is_active and NetworkManager.is_in_lobby() and not _network_spawn_initialized:
		_network_spawn_initialized = true
		player.global_position = Vector2((NetworkManager.local_peer_id - 1) * 72.0, (NetworkManager.local_peer_id - 1) * 28.0)
	if is_active and not NetworkManager.is_world_authority():
		_clear_local_world_simulation()
	if not is_active:
		pause_menu.hide()
		level_up_screen.hide()
	GameManager.set_paused(not is_active)


func _clear_local_world_simulation() -> void:
	for enemy in GameManager.enemies.duplicate():
		if is_instance_valid(enemy) and not enemy is RemoteWorldActor:
			enemy.queue_free()
	if is_instance_valid(GameManager.current_boss):
		GameManager.current_boss.queue_free()


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
