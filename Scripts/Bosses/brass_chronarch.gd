class_name BrassChronarch
extends BossController


func perform_attack(sequence: int) -> void:
	if not is_instance_valid(GameManager.player):
		return
	match sequence % 3:
		0:
			_clock_hand_crossfire(sequence)
		1:
			var shots := 5 + current_phase * 2
			spawn_fan_projectiles(shots, 54.0 + current_phase * 14.0, 520.0 + current_phase * 45.0, 14.0 + current_phase * 4.0, 8.0, definition.secondary_color)
			if current_phase >= 2:
				spawn_radial_projectiles(6 + current_phase * 2, 275.0, 13.0 + current_phase * 3.0, 8.0, definition.primary_color, sequence * 0.2)
		2:
			_time_skip()


func _clock_hand_crossfire(sequence: int) -> void:
	var hand_count := 2 + current_phase
	var base_angle := global_position.direction_to(GameManager.player.global_position).angle()
	for hand in range(hand_count):
		var angle := base_angle + TAU * hand / hand_count + sequence * 0.09
		spawn_line_hazard(global_position, angle, 980.0, 30.0 + current_phase * 5.0, 0.95 - current_phase * 0.1, 24.0 + current_phase * 7.0, definition.primary_color)
	if current_phase >= 3:
		spawn_circle_hazard(GameManager.player.global_position, 125.0, 0.7, 38.0, definition.secondary_color)


func _time_skip() -> void:
	var old_position := global_position
	var player_position := GameManager.player.global_position
	var escape_angle := randf_range(0.0, TAU)
	global_position = player_position + Vector2.RIGHT.rotated(escape_angle) * (310.0 + current_phase * 25.0)
	spawn_circle_hazard(old_position, 82.0, 0.55, 22.0 + current_phase * 5.0, definition.secondary_color)
	spawn_circle_hazard(global_position, 105.0, 0.7, 28.0 + current_phase * 6.0, definition.primary_color)
	spawn_radial_projectiles(7 + current_phase * 2, 330.0, 12.0 + current_phase * 4.0, 7.0, definition.secondary_color, _animation_time)
	VFXManager.spawn_death(get_parent(), old_position, definition.primary_color)
	VFXManager.spawn_death(get_parent(), global_position, definition.secondary_color)


func on_phase_changed(phase: int) -> void:
	super.on_phase_changed(phase)
	spawn_radial_projectiles(10 + phase * 3, 240.0 + phase * 30.0, 13.0 + phase * 3.0, 9.0, definition.secondary_color, _animation_time)


func _draw() -> void:
	super._draw()
	for ring in range(2):
		var radius := 67.0 + ring * 13.0
		draw_arc(Vector2.ZERO, radius, -_animation_time * (1.2 + ring), -_animation_time * (1.2 + ring) + PI * 1.65, 36, definition.secondary_color, 4.0, true)
	for hour in range(12):
		var mark := Vector2.RIGHT.rotated(TAU * hour / 12.0) * 79.0
		draw_line(mark * 0.92, mark, definition.primary_color.lightened(0.35), 3.0, true)
	var minute_hand := Vector2.RIGHT.rotated(_animation_time * 2.2) * 55.0
	var hour_hand := Vector2.RIGHT.rotated(-_animation_time * 0.7) * 38.0
	draw_line(Vector2.ZERO, minute_hand, Color("fff1a8"), 5.0, true)
	draw_line(Vector2.ZERO, hour_hand, Color("ff8247"), 7.0, true)
