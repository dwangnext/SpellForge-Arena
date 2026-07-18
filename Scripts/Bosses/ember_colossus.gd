class_name EmberColossus
extends BossController


func perform_attack(sequence: int) -> void:
	var count := 8 + current_phase * 3
	spawn_radial_projectiles(count, 250.0 + current_phase * 35.0, 13.0 + current_phase * 5.0, 12.0, definition.primary_color, sequence * 0.16)
	if current_phase >= 2 and is_instance_valid(GameManager.player):
		var combat_target := NetworkManager.get_nearest_combat_target(global_position)
		spawn_circle_hazard(combat_target.global_position, 95.0 + current_phase * 20.0, 0.85, 24.0 + current_phase * 7.0, definition.secondary_color)
	if current_phase >= 3:
		for offset in [Vector2(150, 0), Vector2(-75, 130), Vector2(-75, -130)]:
			spawn_circle_hazard(global_position + offset, 72.0, 0.65, 34.0, definition.primary_color)


func _draw() -> void:
	super._draw()
	for index in range(6 + current_phase):
		var angle := _animation_time * (0.8 + current_phase * 0.2) + TAU * index / (6 + current_phase)
		var flame_position := Vector2.RIGHT.rotated(angle) * (62.0 + sin(_animation_time * 5.0 + index) * 8.0)
		draw_circle(flame_position, 7.0 + current_phase, definition.secondary_color)
