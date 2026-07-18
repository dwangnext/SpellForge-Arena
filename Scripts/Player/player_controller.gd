class_name PlayerController
extends CharacterBody2D

signal dash_started
signal dash_finished
signal dash_cooldown_changed(remaining: float, duration: float)

@export_category("Movement")
@export_range(50.0, 1000.0, 10.0) var maximum_speed := 330.0
@export_range(100.0, 5000.0, 50.0) var acceleration := 2400.0
@export_range(100.0, 5000.0, 50.0) var deceleration := 3000.0

@export_category("Dash")
@export_range(100.0, 1500.0, 10.0) var dash_speed := 820.0
@export_range(0.05, 1.0, 0.01) var dash_duration := 0.16
@export_range(0.1, 5.0, 0.05) var dash_cooldown := 0.8

@onready var health: HealthComponent = $HealthComponent

var _dash_direction := Vector2.RIGHT
var _dash_time_remaining := 0.0
var _dash_cooldown_remaining := 0.0
var _last_move_direction := Vector2.RIGHT
var _controls_enabled := true
var _animation_time := 0.0
var _riot_shield_active := false
var _weapon_id := "wand"
var _temporary_speed_multiplier := 1.0
var _speed_boost_remaining := 0.0


func _ready() -> void:
	var character := MetaProgression.get_selected_character()
	var health_multiplier := 1.0 + MetaProgression.get_permanent_effect(PermanentUpgradeDefinition.EffectType.HEALTH)
	var movement_multiplier := 1.0 + MetaProgression.get_permanent_effect(PermanentUpgradeDefinition.EffectType.MOVEMENT_SPEED)
	if character != null:
		health_multiplier *= character.health_multiplier
		movement_multiplier *= character.movement_multiplier
		modulate = character.color
	health.maximum_health *= health_multiplier
	health.restore_to_full()
	maximum_speed *= movement_multiplier
	MetaProgression.record_stat("runs_started")
	GameManager.register_player(self)
	health.died.connect(_on_died)
	$SpellCaster.selection_changed.connect(_on_spell_selected)
	queue_redraw()


func _exit_tree() -> void:
	GameManager.unregister_player(self)


func _physics_process(delta: float) -> void:
	_animation_time += delta
	_update_temporary_speed(delta)
	queue_redraw()
	_update_aim()
	_update_dash_cooldown(delta)
	if not _controls_enabled:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
		move_and_slide()
		return
	if _dash_time_remaining > 0.0:
		_process_dash(delta)
	else:
		_process_movement(delta)
		_try_start_dash()
	move_and_slide()


func _update_aim() -> void:
	var aim_delta := InputManager.get_aim_position(get_viewport()) - global_position
	if aim_delta.length_squared() > 0.001:
		rotation = aim_delta.angle()


func _process_movement(delta: float) -> void:
	var input_direction := InputManager.get_movement_vector()
	var target_speed := maximum_speed * _temporary_speed_multiplier
	if input_direction.length_squared() <= 0.0 and InputManager.is_cursor_move_pressed():
		var cursor_offset := InputManager.get_aim_position(get_viewport()) - global_position
		if cursor_offset.length() > 12.0:
			input_direction = cursor_offset.normalized()
			target_speed *= clampf(cursor_offset.length() / 90.0, 0.25, 1.0)
	if input_direction.length_squared() > 0.0:
		_last_move_direction = input_direction.normalized()
		var target_velocity := _last_move_direction * target_speed
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)


func grant_temporary_speed(multiplier: float, duration: float) -> void:
	_temporary_speed_multiplier = maxf(_temporary_speed_multiplier, maxf(multiplier, 1.0))
	_speed_boost_remaining = maxf(_speed_boost_remaining, duration)


func _update_temporary_speed(delta: float) -> void:
	if _speed_boost_remaining <= 0.0:
		_temporary_speed_multiplier = 1.0
		return
	_speed_boost_remaining = maxf(_speed_boost_remaining - delta, 0.0)
	if _speed_boost_remaining <= 0.0:
		_temporary_speed_multiplier = 1.0


func _try_start_dash() -> void:
	if _dash_cooldown_remaining > 0.0 or not InputManager.is_dash_just_pressed():
		return
	_dash_direction = Vector2.RIGHT.rotated(rotation)
	_dash_time_remaining = dash_duration
	_dash_cooldown_remaining = dash_cooldown
	MetaProgression.record_stat("dashes_used")
	velocity = _dash_direction * dash_speed
	dash_started.emit()
	dash_cooldown_changed.emit(_dash_cooldown_remaining, dash_cooldown)


func _process_dash(delta: float) -> void:
	_dash_time_remaining = maxf(_dash_time_remaining - delta, 0.0)
	velocity = _dash_direction * dash_speed
	if _dash_time_remaining <= 0.0:
		dash_finished.emit()


func _update_dash_cooldown(delta: float) -> void:
	if _dash_cooldown_remaining <= 0.0:
		return
	_dash_cooldown_remaining = maxf(_dash_cooldown_remaining - delta, 0.0)
	dash_cooldown_changed.emit(_dash_cooldown_remaining, dash_cooldown)


func apply_damage(amount: float) -> float:
	var mitigated_amount := amount * (0.5 if _riot_shield_active else 1.0)
	var applied := health.take_damage(mitigated_amount)
	if applied > 0.0:
		MetaProgression.record_stat("damage_taken", roundi(applied))
		CameraEffects.shake(clampf(applied * 0.22, 3.0, 13.0), 0.22)
		CameraEffects.flash(Color("ff4f68"), clampf(applied / 100.0, 0.1, 0.35), 0.18)
	return applied


func _on_died() -> void:
	_controls_enabled = false
	velocity = Vector2.ZERO
	$SpellCaster.set_combat_enabled(false)
	modulate = Color(0.45, 0.48, 0.58, 1.0)
	GameManager.notify_player_died()


func _on_spell_selected(_index: int, definition: SpellDefinition) -> void:
	_riot_shield_active = definition != null and definition.id == "riot_shield"
	_weapon_id = definition.weapon_id if definition != null else MetaProgression.selected_weapon_id
	queue_redraw()


func _draw() -> void:
	# Placeholder wizard silhouette, facing local +X.
	var move_amount := clampf(velocity.length() / maxf(maximum_speed, 1.0), 0.0, 1.0)
	var bob := sin(_animation_time * (6.0 + move_amount * 5.0)) * (1.2 + move_amount * 2.0)
	var squash := Vector2(1.0 + move_amount * 0.04, 1.0 - move_amount * 0.04)
	draw_set_transform(Vector2(0, bob), 0.0, squash)
	if _dash_time_remaining > 0.0:
		draw_line(Vector2(-48, 0), Vector2(-14, 0), Color(0.35, 0.88, 1.0, 0.48), 14.0, true)
	draw_circle(Vector2.ZERO, 18.0, Color("6f63d9"))
	draw_colored_polygon(PackedVector2Array([Vector2(-18, 18), Vector2(14, 18), Vector2(-4, -30)]), Color("483b9f"))
	draw_circle(Vector2(2, -11), 9.0, Color("f2c9a0"))
	if _weapon_id == "revolver":
		draw_rect(Rect2(8, -6, 31, 12), Color("d8b35f"), true)
		draw_rect(Rect2(34, -3, 17, 6), Color("f4df9a"), true)
		draw_circle(Vector2(17, 0), 8.0, Color("6a4b8f"))
		draw_circle(Vector2(17, 0), 3.0, Color("ffd447"))
		draw_colored_polygon(PackedVector2Array([Vector2(18, 5), Vector2(30, 17), Vector2(36, 15), Vector2(29, 3)]), Color("6e4931"))
	elif _weapon_id == "gauntlet":
		draw_circle(Vector2(19, 0), 18.0, Color(0.62, 0.16, 0.92, 0.18))
		draw_colored_polygon(PackedVector2Array([Vector2(6, -11), Vector2(28, -16), Vector2(43, -7), Vector2(43, 7), Vector2(28, 16), Vector2(6, 11)]), Color("6f279e"))
		draw_arc(Vector2(29, 0), 11.0, -2.5, 2.5, 18, Color("f16cff"), 4.0, true)
		draw_circle(Vector2(39, 0), 5.5 + sin(_animation_time * 10.0), Color("fff0ff"))
	else:
		draw_line(Vector2(8, 0), Vector2(32, 0), Color("d9b56d"), 5.0, true)
		var glow_radius := 7.0 + sin(_animation_time * 8.0) * 1.5
		draw_circle(Vector2(34, 0), glow_radius + 5.0, Color(0.44, 0.88, 0.96, 0.18))
		draw_circle(Vector2(34, 0), glow_radius, Color("70e1f5"))
	if _riot_shield_active:
		draw_arc(Vector2(22, 0), 27.0, -1.25, 1.25, 24, Color(0.18, 0.95, 1.0, 0.30), 12.0, true)
		draw_arc(Vector2(22, 0), 27.0, -1.25, 1.25, 24, Color(0.78, 0.98, 1.0), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
