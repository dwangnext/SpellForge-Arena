class_name FrostWarden
extends BossController


func perform_attack(sequence: int) -> void:
	spawn_fan_projectiles(5 + current_phase * 2, 72.0 + current_phase * 10.0, 360.0 + current_phase * 35.0, 12.0 + current_phase * 4.0, 10.0, definition.primary_color)
	if current_phase >= 2:
		spawn_circle_hazard(global_position, 145.0 + current_phase * 25.0, 0.75, 22.0 + current_phase * 6.0, definition.secondary_color)
	if sequence % 3 == 0 and is_instance_valid(GameManager.player):
		var combat_target := NetworkManager.get_nearest_combat_target(global_position)
		var retreat := combat_target.global_position.direction_to(global_position)
		global_position = combat_target.global_position + retreat * 360.0
		AudioManager.play_spell_sfx(global_position, 760.0, 0.24)


func _draw() -> void:
	super._draw()
	for index in range(4 + current_phase * 2):
		var angle := -_animation_time * 1.3 + TAU * index / (4 + current_phase * 2)
		var tip := Vector2.RIGHT.rotated(angle) * 72.0
		draw_line(tip * 0.65, tip, definition.secondary_color, 5.0, true)
		draw_circle(tip, 5.0, definition.primary_color.lightened(0.35))
