extends Node

signal pause_changed(is_paused: bool)
signal player_registered(player: Node)
signal player_died
signal rewards_changed(experience: int, coins: int)
signal boss_registered(boss: Node2D, definition: BossDefinition)
signal boss_health_changed(current_health: float, maximum_health: float)
signal boss_phase_changed(phase: int)
signal boss_defeated(definition: BossDefinition)
signal boss_reward_collected(reward_id: String, reward_name: String)
signal cheats_enabled_changed(enabled: bool)
signal owner_access_changed(enabled: bool)

var player: Node2D = null
var is_game_paused := false
var experience := 0
var coins := 0
var enemies: Array[Node2D] = []
var current_boss: Node2D = null
var boss_rewards: Dictionary = {}
var cheats_enabled := false
var owner_access_enabled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func enable_cheats() -> void:
	if cheats_enabled:
		return
	cheats_enabled = true
	cheats_enabled_changed.emit(true)


func enable_owner_access() -> void:
	if owner_access_enabled:
		return
	owner_access_enabled = true
	owner_access_changed.emit(true)


func register_player(new_player: Node2D) -> void:
	player = new_player
	player_registered.emit(player)


func unregister_player(existing_player: Node2D) -> void:
	if player == existing_player:
		player = null


func set_paused(should_pause: bool) -> void:
	var state_changed := is_game_paused != should_pause
	is_game_paused = should_pause
	get_tree().paused = should_pause
	if state_changed:
		pause_changed.emit(should_pause)


func toggle_pause() -> void:
	set_paused(not is_game_paused)


func notify_player_died() -> void:
	MetaProgression.record_stat("player_deaths")
	MetaProgression.record_stat("runs_completed")
	player_died.emit()


func register_enemy(enemy: Node2D) -> void:
	if not enemies.has(enemy):
		enemies.append(enemy)


func unregister_enemy(enemy: Node2D) -> void:
	enemies.erase(enemy)


func register_boss(boss: Node2D, definition: BossDefinition) -> void:
	current_boss = boss
	boss_registered.emit(boss, definition)


func update_boss_health(current_health: float, maximum_health: float) -> void:
	boss_health_changed.emit(current_health, maximum_health)


func update_boss_phase(phase: int) -> void:
	boss_phase_changed.emit(phase)


func notify_boss_defeated(boss: Node2D, definition: BossDefinition) -> void:
	if current_boss == boss:
		current_boss = null
	MetaProgression.record_stat("bosses_defeated")
	boss_defeated.emit(definition)


func add_boss_reward(reward_id: String, reward_name: String) -> void:
	if reward_id.is_empty() or boss_rewards.has(reward_id):
		return
	boss_rewards[reward_id] = true
	MetaProgression.collect_relic(reward_id)
	boss_reward_collected.emit(reward_id, reward_name)


func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	experience += amount
	MetaProgression.record_stat("experience_collected", amount)
	rewards_changed.emit(experience, coins)


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	MetaProgression.add_coins(amount)
	rewards_changed.emit(experience, coins)


func reset_session_state() -> void:
	player = null
	experience = 0
	coins = 0
	enemies.clear()
	current_boss = null
	boss_rewards.clear()
	rewards_changed.emit(experience, coins)
	set_paused(false)
