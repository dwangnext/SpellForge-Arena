class_name TempestEngine
extends BossController


func perform_attack(sequence: int) -> void:
	if not is_instance_valid(GameManager.player):
		return
	match sequence % 3:
		0:
			_turbine_spiral(sequence)
		1:
			_storm_corridors(sequence)
		2:
			_cyclone_dash()


func _turbine_spiral(sequence: int) -> void:
	var spoke_count := 7 + current_phase * 3
	for wave in range(1 + current_phase):
		spawn_radial_projectiles(spoke_count, 235.0 + wave * 72.0, 13.0 + current_phase * 4.0, 9.0, definition.primary_color.lerp(definition.secondary_color, wave * 0.24), sequence * 0.2 + wave * 0.3)


func _storm_corridors(sequence: int) -> void:
	var combat_target := NetworkManager.get_nearest_combat_target(global_position)
	var aim := global_position.direction_to(combat_target.global_position).angle()
	var corridor_count := 2 + current_phase
	for corridor in range(corridor_count):
		var angle := aim + TAU * corridor / corridor_count + sequence * 0.07
		spawn_line_hazard(global_position, angle, 1120.0, 46.0 + current_phase * 5.0, 1.0 - current_phase * 0.1, 28.0 + current_phase * 7.0, definition.secondary_color)
	if current_phase >= 2:
		spawn_circle_hazard(combat_target.global_position, 120.0 + current_phase * 18.0, 0.85, 29.0 + current_phase * 6.0, definition.primary_color)


func _cyclone_dash() -> void:
	var old_position := global_position
	var combat_target := NetworkManager.get_nearest_combat_target(global_position)
	var player_position := combat_target.global_position
	var dash_direction := old_position.direction_to(player_position)
	var destination := player_position + dash_direction * 390.0
	var distance := old_position.distance_to(destination)
	spawn_line_hazard(old_position, dash_direction.angle(), distance, 74.0 + current_phase * 8.0, 0.78, 34.0 + current_phase * 8.0, definition.primary_color)
	global_position = destination
	spawn_radial_projectiles(8 + current_phase * 3, 350.0, 15.0 + current_phase * 4.0, 9.0, definition.secondary_color, _animation_time)
	VFXManager.spawn_death(get_parent(), old_position, definition.secondary_color)
	VFXManager.spawn_death(get_parent(), destination, definition.primary_color)
	CameraEffects.shake(10.0, 0.28)


func on_phase_changed(phase: int) -> void:
	super.on_phase_changed(phase)
	spawn_radial_projectiles(12 + phase * 4, 390.0, 14.0 + phase * 4.0, 8.0, definition.primary_color, _animation_time)


func _draw() -> void:
	super._draw()
	for blade in range(6 + current_phase * 2):
		var angle := _animation_time * (1.7 + current_phase * 0.25) + TAU * blade / (6 + current_phase * 2)
		var inner := Vector2.RIGHT.rotated(angle) * 48.0
		var outer := Vector2.RIGHT.rotated(angle + 0.24) * 84.0
		draw_colored_polygon(PackedVector2Array([inner + Vector2.RIGHT.rotated(angle + PI * 0.5) * 6.0, outer, inner + Vector2.RIGHT.rotated(angle - PI * 0.5) * 6.0]), Color(definition.secondary_color, 0.82))
	draw_circle(Vector2.ZERO, 19.0, Color("d9fbff"))
	draw_circle(Vector2.ZERO, 10.0, definition.primary_color)
