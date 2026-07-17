class_name VerdantMatriarch
extends BossController


func perform_attack(sequence: int) -> void:
	if not is_instance_valid(GameManager.player):
		return
	match sequence % 3:
		0:
			_seed_fan()
		1:
			_plant_chain_garden()
		2:
			_raise_thorn_cage()


func _seed_fan() -> void:
	spawn_fan_projectiles(6 + current_phase * 2, 92.0 + current_phase * 14.0, 320.0 + current_phase * 35.0, 15.0 + current_phase * 4.0, 11.0, definition.primary_color)
	if current_phase >= 2:
		spawn_radial_projectiles(6 + current_phase * 2, 210.0, 12.0 + current_phase * 3.0, 9.0, definition.secondary_color, _animation_time)


func _plant_chain_garden() -> void:
	var center := GameManager.player.global_position
	var bloom_count := 4 + current_phase * 2
	for bloom in range(bloom_count):
		var angle := TAU * bloom / bloom_count + randf_range(-0.15, 0.15)
		var radius := 45.0 + (bloom % 3) * 95.0
		var position := center + Vector2.RIGHT.rotated(angle) * radius
		_spawn_delayed_bloom(position, bloom * 0.22, 68.0 + current_phase * 7.0, 23.0 + current_phase * 6.0)


func _spawn_delayed_bloom(position: Vector2, delay: float, radius: float, damage: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(self) or _is_dying:
		return
	spawn_circle_hazard(position, radius, 0.75, damage, definition.primary_color)


func _raise_thorn_cage() -> void:
	var center := GameManager.player.global_position
	var half_size := 175.0 + current_phase * 20.0
	for side in range(4):
		var angle := side * PI * 0.5
		var origin := center + Vector2.RIGHT.rotated(angle - PI * 0.5) * half_size
		spawn_line_hazard(origin, angle, half_size * 2.0, 34.0, 0.9, 26.0 + current_phase * 7.0, definition.secondary_color)
	if current_phase >= 3:
		spawn_circle_hazard(center, 98.0, 1.0, 42.0, definition.primary_color)


func on_phase_changed(phase: int) -> void:
	super.on_phase_changed(phase)
	for bloom in range(5 + phase):
		var position := global_position + Vector2.RIGHT.rotated(TAU * bloom / (5 + phase)) * 145.0
		spawn_circle_hazard(position, 58.0, 0.65, 20.0 + phase * 6.0, definition.secondary_color)


func _draw() -> void:
	super._draw()
	for petal in range(7 + current_phase):
		var angle := -_animation_time * 0.45 + TAU * petal / (7 + current_phase)
		var center := Vector2.RIGHT.rotated(angle) * 66.0
		draw_circle(center, 15.0, Color(definition.primary_color, 0.72))
		draw_circle(center + Vector2.RIGHT.rotated(angle) * 8.0, 8.0, definition.secondary_color)
	for vine in range(3):
		var angle := _animation_time * (0.6 + vine * 0.2) + TAU * vine / 3.0
		draw_arc(Vector2.ZERO, 82.0 + vine * 9.0, angle, angle + 1.25, 18, definition.secondary_color, 4.0, true)
