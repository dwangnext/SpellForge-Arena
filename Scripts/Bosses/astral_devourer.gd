class_name AstralDevourer
extends BossController


func perform_attack(sequence: int) -> void:
	if not is_instance_valid(GameManager.player):
		return
	if sequence % 2 == 0:
		_gravity_bloom(sequence)
	else:
		_singularity_lanes(sequence)


func _gravity_bloom(sequence: int) -> void:
	var waves := 1 + current_phase
	for wave in range(waves):
		spawn_radial_projectiles(7 + current_phase * 3, 190.0 + wave * 75.0, 14.0 + current_phase * 4.0, 10.0 + wave, definition.primary_color.lerp(definition.secondary_color, wave * 0.3), sequence * 0.22 + wave * 0.31)
	var player_position := GameManager.player.global_position
	spawn_circle_hazard(player_position, 115.0 + current_phase * 22.0, 0.9, 27.0 + current_phase * 7.0, definition.secondary_color)
	if current_phase >= 2:
		for satellite in range(current_phase + 1):
			var offset := Vector2.RIGHT.rotated(TAU * satellite / (current_phase + 1)) * 205.0
			spawn_circle_hazard(player_position + offset, 64.0, 0.75, 24.0 + current_phase * 5.0, definition.primary_color)


func _singularity_lanes(sequence: int) -> void:
	var aim := global_position.direction_to(GameManager.player.global_position).angle()
	var lane_count := 2 + current_phase
	for lane in range(lane_count):
		var angle := aim + TAU * lane / lane_count + sequence * 0.13
		spawn_line_hazard(global_position, angle, 1080.0, 42.0 + current_phase * 6.0, 1.05 - current_phase * 0.12, 27.0 + current_phase * 8.0, definition.secondary_color)
	if current_phase >= 3:
		var old_position := global_position
		global_position = GameManager.player.global_position + Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * 430.0
		VFXManager.spawn_death(get_parent(), old_position, definition.primary_color)
		VFXManager.spawn_death(get_parent(), global_position, definition.secondary_color)


func on_phase_changed(phase: int) -> void:
	super.on_phase_changed(phase)
	spawn_circle_hazard(global_position, 175.0 + phase * 35.0, 0.65, 30.0 + phase * 8.0, definition.primary_color)
	spawn_radial_projectiles(12 + phase * 4, 300.0, 12.0 + phase * 4.0, 8.0, definition.secondary_color, _animation_time)


func _draw() -> void:
	super._draw()
	draw_circle(Vector2.ZERO, 26.0 + sin(_animation_time * 4.0) * 4.0, Color("090311"))
	for arm in range(5 + current_phase):
		var angle := _animation_time * (0.55 + current_phase * 0.12) + TAU * arm / (5 + current_phase)
		var inner := Vector2.RIGHT.rotated(angle) * 43.0
		var outer := Vector2.RIGHT.rotated(angle + 0.45) * (78.0 + sin(_animation_time * 3.0 + arm) * 9.0)
		draw_line(inner, outer, definition.secondary_color, 6.0, true)
		draw_circle(outer, 7.0, definition.primary_color.lightened(0.2))
