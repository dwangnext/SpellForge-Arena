class_name Spell
extends Node2D

signal finished(spell: Spell)

var definition: SpellDefinition
var caster: Node2D
var cast_origin := Vector2.ZERO
var target_position := Vector2.ZERO
var direction := Vector2.RIGHT
var modifiers := SpellModifiers.new()
var sound_enabled := true
var _circle_shape := CircleShape2D.new()
var _circle_query := PhysicsShapeQueryParameters2D.new()


func configure(spell_definition: SpellDefinition, spell_caster: Node2D, origin: Vector2, target: Vector2, spell_modifiers: SpellModifiers = null) -> void:
	definition = spell_definition
	caster = spell_caster
	modifiers = spell_modifiers if spell_modifiers != null else SpellModifiers.new()
	cast_origin = origin
	global_position = origin
	var unclamped_offset := target - origin
	var distance := minf(unclamped_offset.length(), get_cast_range())
	direction = unclamped_offset.normalized() if unclamped_offset.length_squared() > 0.001 else Vector2.RIGHT.rotated(spell_caster.global_rotation)
	target_position = origin + direction * distance
	global_rotation = direction.angle()


func activate() -> void:
	if MetaProgression.is_fusion_spell_id(definition.id):
		var aura := FusionAura.new()
		aura.configure(definition.primary_color, definition.secondary_color)
		add_child(aura)
	if sound_enabled:
		AudioManager.play_spell_sfx(global_position, definition.sound_pitch_hz, definition.sound_duration)
	queue_redraw()


func finish() -> void:
	finished.emit(self)
	queue_free()


func damage_hurtbox(hurtbox: Area2D, multiplier: float = 1.0, force_direction: Vector2 = Vector2.ZERO) -> bool:
	if not hurtbox.has_method("receive_hit"):
		return false
	var hit_direction := force_direction.normalized()
	if hit_direction.length_squared() <= 0.001:
		hit_direction = (hurtbox.global_position - global_position).normalized()
	var is_critical := modifiers.critical_chance > 0.0 and randf() < modifiers.critical_chance
	var critical_multiplier := modifiers.critical_multiplier if is_critical else 1.0
	var amount := DamageCalculator.calculate(definition.damage * modifiers.damage_multiplier, multiplier * critical_multiplier)
	var payload := DamagePayload.new(amount, caster, hurtbox.global_position, hit_direction, definition.knockback_force)
	payload.status_effects = _roll_status_effects()
	hurtbox.receive_hit(payload)
	return true


func damage_circle(center: Vector2, radius: float, multiplier: float = 1.0) -> int:
	_circle_shape.radius = maxf(radius, 1.0)
	_circle_query.shape = _circle_shape
	_circle_query.transform = Transform2D(0.0, center)
	_circle_query.collision_mask = 16
	_circle_query.collide_with_areas = true
	_circle_query.collide_with_bodies = false
	var results := get_world_2d().direct_space_state.intersect_shape(_circle_query, 128)
	var hit_count := 0
	for result in results:
		var hurtbox := result.get("collider") as Area2D
		if hurtbox != null and damage_hurtbox(hurtbox, multiplier, hurtbox.global_position - center):
			hit_count += 1
	if hit_count > 0 and radius >= 70.0:
		CameraEffects.shake(clampf(radius * 0.035, 2.0, 10.0), 0.16)
	return hit_count


func get_cast_range() -> float:
	return definition.cast_range


func get_speed() -> float:
	return definition.speed * modifiers.projectile_speed_multiplier if supports_projectile_modifiers() else definition.speed


func get_area_radius() -> float:
	return definition.area_radius * modifiers.area_multiplier


func supports_projectile_modifiers() -> bool:
	return false


func _roll_status_effects() -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	if definition.intrinsic_status != "none" and randf() < definition.intrinsic_status_chance:
		var intrinsic := {"type": definition.intrinsic_status, "duration": definition.intrinsic_status_duration}
		if definition.intrinsic_status_damage > 0.0:
			intrinsic["damage"] = definition.intrinsic_status_damage * modifiers.damage_multiplier
		effects.append(intrinsic)
	if modifiers.freeze_chance > 0.0 and randf() < modifiers.freeze_chance:
		effects.append({"type": "freeze", "duration": modifiers.freeze_duration})
	if modifiers.burn_chance > 0.0 and randf() < modifiers.burn_chance:
		effects.append({"type": "burn", "duration": modifiers.burn_duration, "damage": modifiers.burn_damage})
	if modifiers.poison_chance > 0.0 and randf() < modifiers.poison_chance:
		effects.append({"type": "poison", "duration": modifiers.poison_duration, "damage": modifiers.poison_damage})
	return effects
