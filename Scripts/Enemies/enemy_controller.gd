class_name EnemyController
extends CharacterBody2D

const EXPERIENCE_GEM_SCENE := preload("res://Scenes/Pickups/ExperienceGem.tscn")
const COIN_SCENE := preload("res://Scenes/Pickups/Coin.tscn")

@export var definition: EnemyDefinition
@export_range(0.0, 5000.0, 50.0) var steering_acceleration := 900.0

@onready var health: HealthComponent = $HealthComponent
@onready var contact_damage: ContactDamageComponent = $ContactDamageComponent
@onready var status_effects: StatusEffectComponent = $StatusEffectComponent

var _knockback_velocity := Vector2.ZERO
var _is_dying := false
var difficulty_multiplier := 1.0
var experience_multiplier := 1.0
var empowerment_tier := 0
var _animation_time := 0.0


func _ready() -> void:
	if definition == null:
		push_error("Enemy requires an EnemyDefinition resource.")
		set_physics_process(false)
		return
	health.maximum_health = definition.maximum_health * difficulty_multiplier * NetworkManager.get_enemy_health_multiplier()
	health.restore_to_full()
	contact_damage.set_meta("damage", definition.contact_damage * lerpf(1.0, difficulty_multiplier, 0.65))
	scale = Vector2.ONE * definition.visual_scale * (1.0 + empowerment_tier * 0.05)
	health.died.connect(_on_died)
	GameManager.register_enemy(self)
	queue_redraw()


func _exit_tree() -> void:
	GameManager.unregister_enemy(self)


func _physics_process(delta: float) -> void:
	_animation_time += delta
	if status_effects.is_stunned() or status_effects.is_frozen():
		queue_redraw()
	if _is_dying or not is_instance_valid(GameManager.player):
		velocity = velocity.move_toward(Vector2.ZERO, steering_acceleration * delta)
		move_and_slide()
		return
	if status_effects.is_stunned():
		velocity = velocity.move_toward(Vector2.ZERO, steering_acceleration * 2.0 * delta)
		move_and_slide()
		return
	var to_player := GameManager.player.global_position - global_position
	var speed_scale := lerpf(1.0, difficulty_multiplier, 0.18)
	var desired_velocity := to_player.normalized() * definition.movement_speed * speed_scale * status_effects.movement_multiplier
	velocity = velocity.move_toward(desired_velocity, steering_acceleration * delta)
	velocity += _knockback_velocity
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 1800.0 * delta)
	move_and_slide()


func receive_hit(payload: DamagePayload) -> void:
	if _is_dying:
		return
	var final_damage := DamageCalculator.calculate(payload.amount, 1.0, 0.0, definition.defense)
	var applied_damage := health.take_damage(final_damage)
	if applied_damage <= 0.0:
		return
	MetaProgression.record_stat("damage_dealt", roundi(applied_damage))
	_knockback_velocity += payload.knockback_direction * payload.knockback_force
	status_effects.apply_effects(payload.status_effects)
	VFXManager.spawn_damage_number(get_parent(), payload.hit_position, applied_damage, definition.color)
	VFXManager.spawn_hit(get_parent(), payload.hit_position, definition.color)
	AudioManager.play_spell_sfx(payload.hit_position, 310.0 + randf_range(-25.0, 25.0), 0.07)


func _on_died() -> void:
	if _is_dying:
		return
	_is_dying = true
	MetaProgression.record_stat("enemies_defeated")
	_apply_lifesteal_reward()
	_spawn_rewards()
	VFXManager.spawn_death(get_parent(), global_position, definition.color)
	AudioManager.play_spell_sfx(global_position, 150.0, 0.14)
	queue_free()


func _apply_lifesteal_reward() -> void:
	if not is_instance_valid(GameManager.player):
		return
	var upgrades := GameManager.player.get_node_or_null("UpgradeController") as UpgradeController
	var player_health := GameManager.player.get_node_or_null("HealthComponent") as HealthComponent
	if upgrades == null or player_health == null:
		return
	for resource in upgrades.catalog:
		var upgrade := resource as UpgradeDefinition
		if upgrade != null and upgrade.effect_type == UpgradeDefinition.EffectType.LIFESTEAL:
			var stacks := upgrades.get_stack_count(upgrade)
			if stacks > 0:
				player_health.heal(health.maximum_health * upgrade.magnitude * stacks)
			return


func _spawn_rewards() -> void:
	var experience_reward := maxi(roundi(definition.experience_value * experience_multiplier), 1)
	_spawn_pickup(EXPERIENCE_GEM_SCENE, experience_reward, Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0)))
	if randf() <= definition.coin_drop_chance:
		_spawn_pickup(COIN_SCENE, definition.coin_value, Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0)))


func _spawn_pickup(scene: PackedScene, value: int, offset: Vector2) -> void:
	var pickup := scene.instantiate()
	get_parent().add_child(pickup)
	pickup.global_position = global_position + offset
	pickup.value = value


func _draw() -> void:
	if definition == null:
		return
	draw_circle(Vector2.ZERO, 20.0, definition.color.darkened(0.28))
	draw_circle(Vector2(0, -3), 17.0, definition.color)
	draw_circle(Vector2(-6, -6), 3.0, Color.WHITE)
	draw_circle(Vector2(6, -6), 3.0, Color.WHITE)
	draw_circle(Vector2(-6, -6), 1.4, Color("151725"))
	draw_circle(Vector2(6, -6), 1.4, Color("151725"))
	if empowerment_tier > 0:
		var tier_color := Color("ffd447").lerp(Color("b45cff"), clampf((empowerment_tier - 1) * 0.22, 0.0, 1.0))
		draw_arc(Vector2.ZERO, 24.0 + minf(empowerment_tier, 5) * 1.5, 0.0, TAU, 24, Color(tier_color, 0.72), 3.0, true)
		for mark in range(mini(empowerment_tier, 5)):
			var angle := -PI * 0.5 + (mark - (mini(empowerment_tier, 5) - 1) * 0.5) * 0.32
			draw_circle(Vector2.RIGHT.rotated(angle) * 27.0, 2.5, tier_color)
	if status_effects.is_stunned():
		for spark in range(3):
			var spark_angle := _animation_time * 5.0 + TAU * spark / 3.0
			var spark_position := Vector2.RIGHT.rotated(spark_angle) * 29.0
			draw_colored_polygon(PackedVector2Array([spark_position + Vector2(-3, -5), spark_position + Vector2(2, -1), spark_position + Vector2(-1, 5), spark_position + Vector2(5, 0)]), Color("ffe45c"))
	elif status_effects.is_frozen():
		draw_arc(Vector2.ZERO, 23.0, 0.0, TAU, 24, Color(0.45, 0.9, 1.0, 0.85), 4.0, true)
