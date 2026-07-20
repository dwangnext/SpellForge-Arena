class_name SpawnerStructure
extends StaticBody2D

const SPACE_TIER_NAMES := ["Fly", "Delta", "Pioneer", "Crusader", "Marauder"]
const SPACE_TIER_COSTS := [30, 60, 110, 180, 300]
const FINAL_SPACE_TIER := 5
const MAX_UNITS_PER_STRUCTURE := 5

var structure_id := "frontier_tent"
var display_name := "Frontier Tent"
var accent_color := Color("75e6a4")
var maximum_health := 60.0
var current_health := 60.0
var spawn_interval := 3.8
var unit_health := 15.0
var unit_damage := 10.0
var ranged_units := false
var _spawn_remaining := 1.0
var _space_tier := 0
var _space_path := ""
var _is_destroyed := false
var _spawned_units: Array[SpawnerUnit] = []


func configure(id: String, title: String, position: Vector2, color: Color) -> void:
	structure_id = id
	display_name = title
	global_position = position
	accent_color = color
	match structure_id:
		"ranger_outpost":
			maximum_health = 70.0
			spawn_interval = 3.5
			unit_health = 20.0
			unit_damage = 12.0
			ranged_units = true
		"military_base":
			maximum_health = 80.0
			spawn_interval = 3.0
			unit_health = 30.0
			unit_damage = 17.0
			ranged_units = true
		"space_camp":
			maximum_health = 50.0
			spawn_interval = 4.0
			unit_health = 25.0
			unit_damage = 14.0
			ranged_units = true
	current_health = maximum_health


func _ready() -> void:
	add_to_group("allied_targets")
	add_to_group("network_allies")
	if structure_id == "space_camp":
		add_to_group("space_camps")
	collision_layer = 1
	collision_mask = 4
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(72, 58)
	collision.shape = shape
	add_child(collision)
	queue_redraw()
	var structures := get_tree().get_nodes_in_group("network_allies").filter(func(node): return node is SpawnerStructure)
	if structures.size() > 10:
		var oldest := structures.front() as SpawnerStructure
		if is_instance_valid(oldest) and oldest != self:
			oldest.queue_free()


func _physics_process(delta: float) -> void:
	if _is_destroyed or not NetworkManager.is_world_authority():
		return
	_spawn_remaining -= delta
	if _spawn_remaining <= 0.0:
		_spawn_remaining = spawn_interval
		_spawn_unit()


func apply_damage(amount: float) -> float:
	return _apply_damage_internal(amount * 1.35)


func apply_enemy_contact_damage(amount: float) -> float:
	return _apply_damage_internal(amount)


func _apply_damage_internal(amount: float) -> float:
	if _is_destroyed or amount <= 0.0:
		return 0.0
	var applied := minf(current_health, amount)
	current_health -= applied
	VFXManager.spawn_damage_number(get_parent(), global_position, applied, accent_color)
	queue_redraw()
	if current_health <= 0.0:
		_is_destroyed = true
		VFXManager.spawn_death(get_parent(), global_position, accent_color)
		queue_free()
	return applied


func get_health_ratio() -> float:
	return current_health / maxf(maximum_health, 1.0)


func get_network_actor_data() -> Dictionary:
	var upgrade_state := get_space_upgrade_state()
	return {
		"ally": true, "ally_kind": "structure", "label": display_name,
		"color": accent_color.to_html(false), "radius": 38.0,
		"health": get_health_ratio(), "space_tier": _space_tier,
		"structure_id": structure_id, "ship_variant": _space_path,
		"next_cost": int(upgrade_state.get("next_cost", 0)),
		"choice_required": bool(upgrade_state.get("choice_required", false)),
		"maxed": bool(upgrade_state.get("maxed", false)),
		"tier_name": String(upgrade_state.get("tier_name", "")),
		"next_name": String(upgrade_state.get("next_name", "")),
	}


func _spawn_unit() -> void:
	_prune_spawned_units()
	if _spawned_units.size() >= MAX_UNITS_PER_STRUCTURE:
		return
	var active_units := get_tree().get_nodes_in_group("spawner_units")
	if active_units.size() >= 60:
		var oldest := active_units.front() as Node
		if is_instance_valid(oldest):
			oldest.queue_free()
	var unit := SpawnerUnit.new()
	var is_space := structure_id == "space_camp"
	var tier_scale := 1.0 + _space_tier * 0.24
	unit.configure(
		_space_tier_name() if is_space else ("Rifle Squad" if ranged_units else "Bat Guard"),
		global_position + Vector2(randf_range(-45.0, 45.0), randf_range(-45.0, 45.0)),
		unit_health + (_space_tier * 50.0 if is_space else 0.0),
		unit_damage * tier_scale,
		true if is_space else ranged_units,
		accent_color.lightened(minf(_space_tier * 0.06, 0.3)),
		is_space,
		_space_tier,
		_space_path
	)
	get_parent().add_child(unit)
	_spawned_units.append(unit)


func get_spawned_unit_count() -> int:
	_prune_spawned_units()
	return _spawned_units.size()


func _prune_spawned_units() -> void:
	for index in range(_spawned_units.size() - 1, -1, -1):
		if not is_instance_valid(_spawned_units[index]) or _spawned_units[index].is_queued_for_deletion():
			_spawned_units.remove_at(index)


func request_space_upgrade(choice := "") -> bool:
	if structure_id != "space_camp" or _space_tier >= FINAL_SPACE_TIER:
		return false
	var normalized_choice := choice.to_lower()
	if _space_tier == FINAL_SPACE_TIER - 1 and normalized_choice not in ["odyssey", "aries"]:
		return false
	var cost := int(SPACE_TIER_COSTS[_space_tier])
	if not GameManager.spend_experience(cost):
		return false
	_space_tier += 1
	if _space_tier == FINAL_SPACE_TIER:
		_space_path = normalized_choice
	maximum_health += 50.0
	current_health += 50.0
	spawn_interval = maxf(spawn_interval - 0.18, 2.8)
	AudioManager.play_spell_sfx(global_position, 420.0 + _space_tier * 55.0, 0.32)
	VFXManager.spawn_death(get_parent(), global_position, accent_color.lightened(0.25))
	queue_redraw()
	return true


func get_space_upgrade_state() -> Dictionary:
	var maxed := _space_tier >= FINAL_SPACE_TIER
	var needs_choice := _space_tier == FINAL_SPACE_TIER - 1
	return {
		"tier": _space_tier,
		"tier_name": _space_tier_name(),
		"path": _space_path,
		"next_cost": 0 if maxed else int(SPACE_TIER_COSTS[_space_tier]),
		"choice_required": needs_choice,
		"maxed": maxed,
		"next_name": "FINAL HULL" if needs_choice else (_space_name_for_tier(_space_tier + 1) if not maxed else ""),
	}


func _space_tier_name() -> String:
	if _space_tier >= FINAL_SPACE_TIER:
		return _space_path.capitalize()
	return _space_name_for_tier(_space_tier)


func _space_name_for_tier(tier: int) -> String:
	return String(SPACE_TIER_NAMES[clampi(tier, 0, SPACE_TIER_NAMES.size() - 1)])


func _draw() -> void:
	var size := Vector2(72, 58)
	draw_rect(Rect2(-size * 0.5, size), accent_color.darkened(0.58), true)
	draw_rect(Rect2(-size * 0.5 + Vector2(5, 5), size - Vector2(10, 10)), accent_color.darkened(0.2), true)
	if structure_id == "frontier_tent":
		draw_colored_polygon(PackedVector2Array([Vector2(-38, 18), Vector2(0, -44), Vector2(38, 18)]), accent_color)
	elif structure_id == "space_camp":
		draw_circle(Vector2.ZERO, 25.0, Color("172044"))
		draw_arc(Vector2.ZERO, 31.0, 0.0, TAU, 28, accent_color, 5.0, true)
		draw_circle(Vector2.ZERO, 9.0, Color("9ffcff"))
	else:
		draw_rect(Rect2(-27, -22, 54, 35), accent_color, true)
		draw_rect(Rect2(-6, -42, 12, 24), accent_color.lightened(0.25), true)
	var ratio := get_health_ratio()
	draw_rect(Rect2(-38, -55, 76, 6), Color("11131e"), true)
	draw_rect(Rect2(-38, -55, 76 * ratio, 6), Color("76f29e"), true)
	var subtitle := "%s%s" % [display_name, " — %s T%d" % [_space_tier_name(), _space_tier + 1] if structure_id == "space_camp" else ""]
	draw_string(ThemeDB.fallback_font, Vector2(-68, 48), subtitle, HORIZONTAL_ALIGNMENT_CENTER, 136.0, 12, Color.WHITE)
