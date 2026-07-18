class_name VoidArchitect
extends BossController


func perform_attack(sequence: int) -> void:
	if not is_instance_valid(GameManager.player):
		return
	var combat_target := NetworkManager.get_nearest_combat_target(global_position)
	var aim_angle := global_position.direction_to(combat_target.global_position).angle()
	var beam_count := 1 if current_phase == 1 else current_phase
	for index in range(beam_count):
		var offset := (index - (beam_count - 1) * 0.5) * deg_to_rad(22.0)
		spawn_line_hazard(global_position, aim_angle + offset, 920.0, 38.0 + current_phase * 8.0, 1.05 - current_phase * 0.12, 25.0 + current_phase * 8.0, definition.primary_color)
	if sequence % 2 == 0:
		spawn_radial_projectiles(6 + current_phase * 4, 205.0 + current_phase * 28.0, 15.0 + current_phase * 4.0, 9.0, definition.secondary_color, _animation_time)
	if current_phase >= 3:
		spawn_circle_hazard(combat_target.global_position, 150.0, 1.0, 42.0, definition.secondary_color)


func _draw() -> void:
	super._draw()
	for index in range(3):
		var ring_radius := 64.0 + index * 14.0
		var start := _animation_time * (1.0 + index * 0.35) * (-1.0 if index % 2 else 1.0)
		draw_arc(Vector2.ZERO, ring_radius, start, start + PI * 1.2, 24, definition.secondary_color, 4.0, true)
