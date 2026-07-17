class_name BurstEffect
extends Node2D

@export_range(0.1, 2.0, 0.05) var lifetime := 0.3
@export_range(2.0, 100.0, 1.0) var maximum_radius := 34.0
@export_range(1.0, 20.0, 1.0) var line_width := 5.0

var _effect_color := Color.WHITE
var _elapsed := 0.0
var _particles: Array[Dictionary] = []


func setup(accent_color: Color) -> void:
	_effect_color = accent_color
	if not SettingsManager.reduced_motion:
		for index in range(12):
			var angle := TAU * index / 12.0 + randf_range(-0.16, 0.16)
			_particles.append({
				"position": Vector2.ZERO,
				"velocity": Vector2.RIGHT.rotated(angle) * randf_range(75.0, 180.0),
				"size": randf_range(2.0, 5.0),
			})
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	for particle in _particles:
		particle.position += particle.velocity * delta
		particle.velocity *= maxf(1.0 - delta * 4.0, 0.0)
	queue_redraw()
	if _elapsed >= lifetime:
		queue_free()


func _draw() -> void:
	var progress := clampf(_elapsed / lifetime, 0.0, 1.0)
	var color := _effect_color
	color.a = 1.0 - progress
	draw_arc(Vector2.ZERO, lerpf(4.0, maximum_radius, progress), 0.0, TAU, 24, color, line_width * (1.0 - progress * 0.6), true)
	for particle in _particles:
		draw_circle(particle.position, particle.size * (1.0 - progress * 0.5), color)
