class_name StormRepeaterProjectile
extends AetherRipperProjectile

const CHAIN_DAMAGE_MULTIPLIER := 0.3
const CHAIN_RADIUS_SQUARED := 250.0 * 250.0
const MAX_CHAIN_TARGETS := 3


func _on_area_entered(area: Area2D) -> void:
	var should_chain := not _ended and area.has_method("receive_hit") and not _hit_ids.has(area.get_instance_id())
	super._on_area_entered(area)
	if should_chain:
		_release_chain_lightning(area)


func _release_chain_lightning(primary_hurtbox: Area2D) -> void:
	var candidates: Array[Area2D] = []
	for candidate in GameManager.enemies:
		var enemy := candidate as Node2D
		if enemy == null or enemy.is_queued_for_deletion():
			continue
		var hurtbox := enemy.get_node_or_null("HurtboxComponent") as Area2D
		if hurtbox == null or hurtbox == primary_hurtbox:
			continue
		if primary_hurtbox.global_position.distance_squared_to(hurtbox.global_position) <= CHAIN_RADIUS_SQUARED:
			candidates.append(hurtbox)
	candidates.sort_custom(func(a: Area2D, b: Area2D):
		return primary_hurtbox.global_position.distance_squared_to(a.global_position) < primary_hurtbox.global_position.distance_squared_to(b.global_position)
	)
	var arc_points := PackedVector2Array([primary_hurtbox.global_position])
	var chain_damage := DamageCalculator.calculate(definition.damage * modifiers.damage_multiplier, CHAIN_DAMAGE_MULTIPLIER)
	for index in range(mini(candidates.size(), MAX_CHAIN_TARGETS)):
		var hurtbox := candidates[index]
		var hit_direction := arc_points[arc_points.size() - 1].direction_to(hurtbox.global_position)
		var payload := DamagePayload.new(chain_damage, caster, hurtbox.global_position, hit_direction, definition.knockback_force * 0.25)
		hurtbox.receive_hit(payload)
		arc_points.append(hurtbox.global_position)
		VFXManager.spawn_hit(get_parent(), hurtbox.global_position, definition.primary_color)
	if arc_points.size() > 1:
		var arc := StormChainArc.new()
		get_parent().add_child(arc)
		arc.configure(arc_points, definition.primary_color)
		AudioManager.play_spell_sfx(primary_hurtbox.global_position, 1180.0, 0.09)


func _draw() -> void:
	if definition == null:
		return
	var bolt := PackedVector2Array([
		Vector2(-22, 0), Vector2(-13, -5), Vector2(-6, 4), Vector2(2, -6), Vector2(10, 3), Vector2(20, 0),
	])
	draw_polyline(bolt, Color(definition.primary_color, 0.25), 11.0, true)
	draw_polyline(bolt, definition.primary_color, 4.0, true)
	draw_polyline(bolt, definition.secondary_color, 1.5, true)
	draw_circle(Vector2(20, 0), 4.0, Color.WHITE)
