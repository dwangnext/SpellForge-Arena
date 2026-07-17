extends Node

signal shake_requested(strength: float, duration: float)
signal flash_requested(color: Color, strength: float, duration: float)


func shake(strength: float, duration: float = 0.18) -> void:
	var adjusted := strength * SettingsManager.screen_shake_intensity
	if SettingsManager.reduced_motion:
		adjusted *= 0.2
	if adjusted > 0.01:
		shake_requested.emit(adjusted, duration)


func flash(color: Color, strength: float = 0.3, duration: float = 0.16) -> void:
	var adjusted := strength * SettingsManager.flash_intensity
	if adjusted > 0.01:
		flash_requested.emit(color, adjusted, duration)
