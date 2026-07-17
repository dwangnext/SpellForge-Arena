extends Node

signal settings_changed

const SETTINGS_PATH := "user://spellforge_settings.cfg"

var master_volume := 1.0
var music_volume := 0.7
var sfx_volume := 0.85
var screen_shake_intensity := 1.0
var flash_intensity := 1.0
var reduced_motion := false
var high_contrast := false
var _save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.3
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer.timeout.connect(_write_settings)
	add_child(_save_timer)
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	master_volume = clampf(float(config.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	screen_shake_intensity = clampf(float(config.get_value("accessibility", "screen_shake", screen_shake_intensity)), 0.0, 1.0)
	flash_intensity = clampf(float(config.get_value("accessibility", "flashes", flash_intensity)), 0.0, 1.0)
	reduced_motion = bool(config.get_value("accessibility", "reduced_motion", reduced_motion))
	high_contrast = bool(config.get_value("accessibility", "high_contrast", high_contrast))


func save_settings() -> void:
	settings_changed.emit()
	if _save_timer.is_stopped():
		_save_timer.start()


func _write_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("accessibility", "screen_shake", screen_shake_intensity)
	config.set_value("accessibility", "flashes", flash_intensity)
	config.set_value("accessibility", "reduced_motion", reduced_motion)
	config.set_value("accessibility", "high_contrast", high_contrast)
	config.save(SETTINGS_PATH)


func update_audio(master: float, music: float, sfx: float) -> void:
	master_volume = clampf(master, 0.0, 1.0)
	music_volume = clampf(music, 0.0, 1.0)
	sfx_volume = clampf(sfx, 0.0, 1.0)
	save_settings()


func update_accessibility(shake: float, flashes: float, reduce_motion: bool, contrast: bool) -> void:
	screen_shake_intensity = clampf(shake, 0.0, 1.0)
	flash_intensity = clampf(flashes, 0.0, 1.0)
	reduced_motion = reduce_motion
	high_contrast = contrast
	save_settings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _save_timer != null and not _save_timer.is_stopped():
		_write_settings()
