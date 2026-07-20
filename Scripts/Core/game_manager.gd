extends Node

signal pause_changed(is_paused: bool)
signal player_registered(player: Node)
signal player_died
signal player_revived
signal rewards_changed(experience: int, coins: int)
signal boss_registered(boss: Node2D, definition: BossDefinition)
signal boss_health_changed(current_health: float, maximum_health: float)
signal boss_phase_changed(phase: int)
signal boss_defeated(definition: BossDefinition)
signal boss_reward_collected(reward_id: String, reward_name: String)
signal cheats_enabled_changed(enabled: bool)
signal owner_access_changed(enabled: bool)
signal local_modal_changed(is_blocked: bool)

var player: Node2D = null
var is_game_paused := false
var experience := 0
var coins := 0
var enemies: Array[Node2D] = []
var current_boss: Node2D = null
var active_bosses: Array[Node2D] = []
var boss_rewards: Dictionary = {}
var cheats_enabled := false
var owner_access_enabled := false
var _local_modal_sources: Dictionary = {}


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
	# A co-op run never freezes the shared simulation. Menus block only the
	# wizard who opened them so teammates must protect that player.
	var effective_pause := should_pause and not NetworkManager.is_realtime_coop_session()
	var state_changed := is_game_paused != effective_pause
	is_game_paused = effective_pause
	get_tree().paused = effective_pause
	if state_changed:
		pause_changed.emit(effective_pause)


func toggle_pause() -> void:
	set_paused(not is_game_paused)


func set_local_modal(source: StringName, is_open: bool) -> void:
	var was_blocked := not _local_modal_sources.is_empty()
	if is_open:
		_local_modal_sources[source] = true
	else:
		_local_modal_sources.erase(source)
	var is_blocked := not _local_modal_sources.is_empty()
	if is_instance_valid(player) and player.has_method("set_controls_enabled"):
		player.set_controls_enabled(not is_blocked)
	if was_blocked != is_blocked:
		local_modal_changed.emit(is_blocked)


func is_local_input_blocked() -> bool:
	return not _local_modal_sources.is_empty()


func notify_player_died() -> void:
	# In co-op this signal means "downed", not that the shared run ended. The
	# player may still be revived by a teammate with a boss relic.
	if not NetworkManager.is_realtime_coop_session():
		MetaProgression.record_stat("player_deaths")
		MetaProgression.record_stat("runs_completed")
	player_died.emit()


func register_enemy(enemy: Node2D) -> void:
	if not enemies.has(enemy):
		enemies.append(enemy)


func unregister_enemy(enemy: Node2D) -> void:
	enemies.erase(enemy)


func register_boss(boss: Node2D, definition: BossDefinition) -> void:
	if not active_bosses.has(boss):
		active_bosses.append(boss)
	current_boss = boss
	boss_registered.emit(boss, definition)


func update_boss_health(current_health: float, maximum_health: float) -> void:
	boss_health_changed.emit(current_health, maximum_health)


func update_boss_phase(phase: int) -> void:
	boss_phase_changed.emit(phase)


func notify_boss_defeated(boss: Node2D, definition: BossDefinition) -> void:
	active_bosses.erase(boss)
	if current_boss == boss:
		current_boss = active_bosses.front() if not active_bosses.is_empty() else null
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


func spend_experience(amount: int) -> bool:
	if amount <= 0 or experience < amount:
		return false
	experience -= amount
	rewards_changed.emit(experience, coins)
	return true


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	MetaProgression.add_coins(amount)
	rewards_changed.emit(experience, coins)


func synchronize_shared_rewards(shared_experience: int, shared_coins: int) -> void:
	var safe_experience := maxi(shared_experience, 0)
	var safe_coins := maxi(shared_coins, 0)
	var new_coin_reward := maxi(safe_coins - coins, 0)
	experience = safe_experience
	coins = safe_coins
	if new_coin_reward > 0:
		MetaProgression.add_coins(new_coin_reward)
	rewards_changed.emit(experience, coins)


func reset_session_state() -> void:
	player = null
	experience = 0
	coins = 0
	enemies.clear()
	current_boss = null
	active_bosses.clear()
	boss_rewards.clear()
	_local_modal_sources.clear()
	rewards_changed.emit(experience, coins)
	set_paused(false)
