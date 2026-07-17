class_name BossController
extends CharacterBody2D

const HAZARD_SCENE := preload("res://Scenes/Hazards/BossHazard.tscn")
const PROJECTILE_SCENE := preload("res://Scenes/Hazards/BossProjectile.tscn")
const REWARD_SCENE := preload("res://Scenes/Pickups/BossReward.tscn")

@export var definition: BossDefinition
@export_range(0.0, 5000.0, 10.0) var steering_acceleration := 520.0
@export_range(50.0, 1000.0, 10.0) var preferred_distance := 250.0

@onready var health: HealthComponent = $HealthComponent
@onready var status_effects: StatusEffectComponent = $StatusEffectComponent
@onready var contact_damage: ContactDamageComponent = $ContactDamageComponent

var current_phase := 1
var _attack_remaining := 1.5
var _knockback_velocity := Vector2.ZERO
var _animation_time := 0.0
var _is_dying := false
var _attack_sequence := 0


func _ready() -> void:
	if definition == null:
		push_error("Boss requires a BossDefinition.")
		set_physics_process(false)
		return
	for error in definition.get_validation_errors():
		push_error("%s: %s" % [definition.display_name, error])
	health.maximum_health = definition.maximum_health * NetworkManager.get_enemy_health_multiplier()
	health.restore_to_full()
	contact_damage.set_meta("damage", definition.contact_damage)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	GameManager.register_boss(self, definition)
	GameManager.update_boss_health(health.current_health, health.maximum_health)
	GameManager.update_boss_phase(current_phase)
	queue_redraw()


func _exit_tree() -> void:
	if GameManager.current_boss == self and not _is_dying:
		GameManager.current_boss = null


func _physics_process(delta: float) -> void:
	_animation_time += delta
	queue_redraw()
	if _is_dying or not is_instance_valid(GameManager.player):
		velocity = velocity.move_toward(Vector2.ZERO, steering_acceleration * delta)
		move_and_slide()
		return
	if status_effects.is_stunned():
		velocity = velocity.move_toward(Vector2.ZERO, steering_acceleration * 2.0 * delta)
		move_and_slide()
		return
	_update_movement(delta)
	_attack_remaining -= delta
	if _attack_remaining <= 0.0:
		_attack_sequence += 1
		perform_attack(_attack_sequence)
		_attack_remaining = definition.attack_interval * maxf(1.0 - (current_phase - 1) * 0.18, 0.48)
	move_and_slide()


func _update_movement(delta: float) -> void:
	var offset := GameManager.player.global_position - global_position
	var direction_to_player := offset.normalized()
	var desired_velocity := Vector2.ZERO
	if offset.length() > preferred_distance:
		desired_velocity = direction_to_player * definition.movement_speed * status_effects.movement_multiplier
	else:
		desired_velocity = direction_to_player.rotated(PI * 0.5) * definition.movement_speed * 0.55
	velocity = velocity.move_toward(desired_velocity, steering_acceleration * delta)
	velocity += _knockback_velocity
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 1500.0 * delta)


func perform_attack(_sequence: int) -> void:
	push_warning("Boss subclass has no attack implementation.")


func receive_hit(payload: DamagePayload) -> void:
	if _is_dying:
		return
	var final_damage := DamageCalculator.calculate(payload.amount, 1.0, 0.0, definition.defense)
	var applied_damage := health.take_damage(final_damage)
	if applied_damage <= 0.0:
		return
	MetaProgression.record_stat("damage_dealt", roundi(applied_damage))
	# Bosses retain hit feedback without being displaced across the arena by rapid-fire builds.
	_knockback_velocity += payload.knockback_direction * payload.knockback_force * 0.035
	status_effects.apply_effects(payload.status_effects, definition.status_duration_multiplier)
	VFXManager.spawn_damage_number(get_parent(), payload.hit_position, applied_damage, definition.primary_color)
	VFXManager.spawn_hit(get_parent(), payload.hit_position, definition.primary_color)
	AudioManager.play_spell_sfx(payload.hit_position, 190.0, 0.11)
	CameraEffects.shake(2.5, 0.1)


func spawn_circle_hazard(position: Vector2, radius: float, warning: float, damage: float, color: Color) -> void:
	var hazard := HAZARD_SCENE.instantiate() as BossHazard
	hazard.configure_circle(position, radius, warning, 0.32, damage, color)
	get_parent().add_child(hazard)


func spawn_line_hazard(position: Vector2, angle: float, length: float, width: float, warning: float, damage: float, color: Color) -> void:
	var hazard := HAZARD_SCENE.instantiate() as BossHazard
	hazard.configure_line(position, angle, length, width, warning, 0.38, damage, color)
	get_parent().add_child(hazard)


func spawn_projectile(travel_direction: Vector2, speed: float, damage: float, radius: float, color: Color) -> void:
	var projectile := PROJECTILE_SCENE.instantiate() as BossProjectile
	projectile.configure(global_position, travel_direction, speed, damage, radius, color)
	get_parent().add_child(projectile)


func spawn_radial_projectiles(count: int, speed: float, damage: float, radius: float, color: Color, angle_offset: float = 0.0) -> void:
	for index in range(count):
		spawn_projectile(Vector2.RIGHT.rotated(angle_offset + TAU * index / count), speed, damage, radius, color)


func spawn_fan_projectiles(count: int, spread_degrees: float, speed: float, damage: float, radius: float, color: Color) -> void:
	if not is_instance_valid(GameManager.player):
		return
	var center_angle := global_position.direction_to(GameManager.player.global_position).angle()
	for index in range(count):
		var fraction := 0.5 if count == 1 else float(index) / (count - 1)
		var offset := deg_to_rad(lerpf(-spread_degrees * 0.5, spread_degrees * 0.5, fraction))
		spawn_projectile(Vector2.RIGHT.rotated(center_angle + offset), speed, damage, radius, color)


func _on_health_changed(current: float, maximum: float) -> void:
	GameManager.update_boss_health(current, maximum)
	var next_phase := definition.get_phase_for_ratio(current / maximum)
	if next_phase != current_phase:
		current_phase = next_phase
		_attack_remaining = minf(_attack_remaining, 0.6)
		GameManager.update_boss_phase(current_phase)
		on_phase_changed(current_phase)


func on_phase_changed(_phase: int) -> void:
	AudioManager.play_spell_sfx(global_position, 105.0 + current_phase * 45.0, 0.5)
	VFXManager.spawn_death(get_parent(), global_position, definition.secondary_color)
	CameraEffects.shake(12.0, 0.45)
	CameraEffects.flash(definition.secondary_color, 0.22, 0.2)


func _on_died() -> void:
	if _is_dying:
		return
	_is_dying = true
	_wipe_nearby_enemies()
	_start_coin_storm()
	_spawn_reward()
	VFXManager.spawn_death(get_parent(), global_position, definition.primary_color)
	AudioManager.play_spell_sfx(global_position, 72.0, 0.8)
	CameraEffects.shake(18.0, 0.6)
	CameraEffects.flash(definition.primary_color, 0.4, 0.28)
	GameManager.notify_boss_defeated(self, definition)
	queue_free()


func _wipe_nearby_enemies() -> void:
	for candidate in GameManager.enemies.duplicate():
		var enemy := candidate as Node2D
		if enemy == null or enemy.is_queued_for_deletion() or global_position.distance_squared_to(enemy.global_position) > 1000.0 * 1000.0:
			continue
		if enemy.has_method("receive_hit"):
			var direction := global_position.direction_to(enemy.global_position)
			enemy.receive_hit(DamagePayload.new(999999.0, self, enemy.global_position, direction, 1400.0))


func _start_coin_storm() -> void:
	var storm := BossCoinStorm.new()
	get_parent().add_child(storm)
	storm.configure(global_position, definition.secondary_color)


func _spawn_reward() -> void:
	var reward := REWARD_SCENE.instantiate() as BossRewardPickup
	reward.configure(definition)
	get_parent().add_child(reward)
	reward.global_position = global_position


func _draw() -> void:
	if definition == null:
		return
	var pulse := 1.0 + sin(_animation_time * (2.0 + current_phase)) * 0.06
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * pulse)
	draw_circle(Vector2.ZERO, 48.0, definition.primary_color.darkened(0.42))
	draw_circle(Vector2.ZERO, 39.0, definition.primary_color)
	draw_arc(Vector2.ZERO, 54.0 + current_phase * 4.0, _animation_time, _animation_time + PI * 1.4, 32, definition.secondary_color, 6.0, true)
	if status_effects.is_stunned():
		for spark in range(4):
			var spark_angle := -_animation_time * 4.0 + TAU * spark / 4.0
			var spark_position := Vector2.RIGHT.rotated(spark_angle) * 68.0
			draw_colored_polygon(PackedVector2Array([spark_position + Vector2(-5, -8), spark_position + Vector2(3, -2), spark_position + Vector2(-2, 8), spark_position + Vector2(7, 0)]), Color("ffe45c"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
