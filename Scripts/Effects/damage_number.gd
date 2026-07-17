extends Node2D

@export_range(0.1, 3.0, 0.05) var lifetime := 0.7
@export var rise_speed := 58.0

@onready var label: Label = $Label
var _elapsed := 0.0
var _horizontal_drift := 0.0


func setup(amount: float, accent_color: Color) -> void:
	label.text = str(roundi(amount))
	label.modulate = accent_color.lightened(0.35)
	_horizontal_drift = randf_range(-18.0, 18.0)
	scale = Vector2(0.72, 0.72)


func _process(delta: float) -> void:
	_elapsed += delta
	position.y -= rise_speed * delta
	position.x += _horizontal_drift * delta
	scale = scale.lerp(Vector2.ONE, minf(delta * 14.0, 1.0))
	modulate.a = 1.0 - clampf(_elapsed / lifetime, 0.0, 1.0)
	if _elapsed >= lifetime:
		queue_free()
