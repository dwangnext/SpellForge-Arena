extends Camera2D

var _shake_strength := 0.0
var _shake_remaining := 0.0
var _shake_duration := 0.0


func _ready() -> void:
	CameraEffects.shake_requested.connect(_on_shake_requested)


func _process(delta: float) -> void:
	if _shake_remaining <= 0.0:
		offset = offset.lerp(Vector2.ZERO, minf(delta * 18.0, 1.0))
		return
	_shake_remaining = maxf(_shake_remaining - delta, 0.0)
	var falloff := _shake_remaining / maxf(_shake_duration, 0.001)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength * falloff


func _on_shake_requested(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_duration = maxf(duration, 0.01)
	_shake_remaining = maxf(_shake_remaining, duration)
