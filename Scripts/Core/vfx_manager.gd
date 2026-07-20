extends Node

const DAMAGE_NUMBER_SCENE := preload("res://Scenes/Effects/DamageNumber.tscn")
const HIT_EFFECT_SCENE := preload("res://Scenes/Effects/HitEffect.tscn")
const DEATH_EFFECT_SCENE := preload("res://Scenes/Effects/DeathEffect.tscn")

const MAX_DAMAGE_NUMBERS := 48
const MAX_BURST_EFFECTS := 72

var _active_damage_numbers := 0
var _active_bursts := 0
var _damage_event_sequence := 0
var _network_damage_events: Array[Dictionary] = []


func spawn_damage_number(parent: Node, world_position: Vector2, amount: float, color: Color) -> void:
	if parent == null or _active_damage_numbers >= MAX_DAMAGE_NUMBERS:
		return
	var number := DAMAGE_NUMBER_SCENE.instantiate()
	_active_damage_numbers += 1
	number.tree_exited.connect(func(): _active_damage_numbers = maxi(_active_damage_numbers - 1, 0))
	parent.add_child(number)
	number.global_position = world_position
	number.setup(amount, color)
	if NetworkManager.is_world_authority():
		_damage_event_sequence += 1
		_network_damage_events.append({
			"id": _damage_event_sequence,
			"x": world_position.x,
			"y": world_position.y,
			"amount": amount,
			"color": color.to_html(false),
			"created": Time.get_ticks_msec(),
		})
		while _network_damage_events.size() > 32:
			_network_damage_events.pop_front()


func get_recent_network_damage_events() -> Array[Dictionary]:
	var cutoff := Time.get_ticks_msec() - 1400
	while not _network_damage_events.is_empty() and int(_network_damage_events.front().get("created", 0)) < cutoff:
		_network_damage_events.pop_front()
	return _network_damage_events.duplicate(true)


func spawn_hit(parent: Node, world_position: Vector2, color: Color) -> void:
	_spawn_burst(HIT_EFFECT_SCENE, parent, world_position, color)


func spawn_death(parent: Node, world_position: Vector2, color: Color) -> void:
	_spawn_burst(DEATH_EFFECT_SCENE, parent, world_position, color)


func _spawn_burst(scene: PackedScene, parent: Node, world_position: Vector2, color: Color) -> void:
	if parent == null or _active_bursts >= MAX_BURST_EFFECTS:
		return
	var effect := scene.instantiate()
	_active_bursts += 1
	effect.tree_exited.connect(func(): _active_bursts = maxi(_active_bursts - 1, 0))
	parent.add_child(effect)
	effect.global_position = world_position
	effect.setup(color)
