extends Node

const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const SPELL_SAMPLE_RATE := 22050
const MAX_SIMULTANEOUS_SFX := 32

var _spell_sound_cache: Dictionary = {}
var _music_cache: Dictionary = {}
var _music_player: AudioStreamPlayer
var _active_sfx := 0
var _music_state := "arena"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)
	SettingsManager.settings_changed.connect(_apply_settings)
	GameManager.boss_registered.connect(func(_boss, _definition): set_music_state("boss"))
	GameManager.boss_defeated.connect(func(_definition): set_music_state("arena"))
	_apply_settings()
	set_music_state("arena", true)
	_music_cache["boss"] = _create_music_track(true)


func set_master_volume(linear_value: float) -> void:
	_set_bus_volume(MASTER_BUS, linear_value)


func set_music_volume(linear_value: float) -> void:
	_set_bus_volume(MUSIC_BUS, linear_value)


func set_sfx_volume(linear_value: float) -> void:
	_set_bus_volume(SFX_BUS, linear_value)


func get_master_volume() -> float:
	var bus_index := AudioServer.get_bus_index(MASTER_BUS)
	if bus_index < 0:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus_index))


func set_master_muted(is_muted: bool) -> void:
	var bus_index := AudioServer.get_bus_index(MASTER_BUS)
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, is_muted)


func _set_bus_volume(bus_name: String, linear_value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var safe_value := clampf(linear_value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(safe_value, 0.0001)))


func play_spell_sfx(world_position: Vector2, pitch_hz: float, duration: float = 0.18) -> void:
	if _active_sfx >= MAX_SIMULTANEOUS_SFX:
		return
	var cache_key := "%d_%d" % [roundi(pitch_hz), roundi(duration * 1000.0)]
	var stream: AudioStreamWAV = _spell_sound_cache.get(cache_key)
	if stream == null:
		stream = _create_spell_tone(pitch_hz, duration)
		_spell_sound_cache[cache_key] = stream
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var player := AudioStreamPlayer2D.new()
	_active_sfx += 1
	player.stream = stream
	player.bus = SFX_BUS
	player.volume_db = -10.0
	current_scene.add_child(player)
	player.global_position = world_position
	player.finished.connect(func():
		_active_sfx = maxi(_active_sfx - 1, 0)
		player.queue_free()
	)
	player.play()


func set_music_state(state: String, immediate: bool = false) -> void:
	if _music_player == null or (state == _music_state and _music_player.playing):
		return
	_music_state = state
	var stream: AudioStreamWAV = _music_cache.get(state)
	if stream == null:
		stream = _create_music_track(state == "boss")
		_music_cache[state] = stream
	if immediate or SettingsManager.reduced_motion:
		_music_player.stream = stream
		_music_player.volume_db = 0.0
		_music_player.play()
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_music_player, "volume_db", -28.0, 0.35)
	tween.tween_callback(func():
		_music_player.stream = stream
		_music_player.play()
	)
	tween.tween_property(_music_player, "volume_db", 0.0, 0.55)


func _create_spell_tone(pitch_hz: float, duration: float) -> AudioStreamWAV:
	var sample_count := maxi(roundi(SPELL_SAMPLE_RATE * duration), 1)
	var bytes := PackedByteArray()
	bytes.resize(sample_count)
	for index in range(sample_count):
		var time := float(index) / SPELL_SAMPLE_RATE
		var envelope := 1.0 - float(index) / sample_count
		var fundamental := sin(TAU * pitch_hz * time)
		var overtone := sin(TAU * pitch_hz * 2.03 * time) * 0.28
		bytes[index] = clampi(roundi(128.0 + (fundamental + overtone) * envelope * 72.0), 0, 255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = SPELL_SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream


func _create_music_track(is_boss: bool) -> AudioStreamWAV:
	var duration := 8.0
	var sample_count := roundi(SPELL_SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var melody := [52, 55, 59, 60, 59, 55, 52, 50, 52, 55, 59, 64, 62, 59, 55, 50,
		52, 55, 59, 60, 64, 62, 59, 55, 57, 60, 64, 67, 64, 60, 59, 55]
	var bass_roots := [40, 36, 43, 38] if is_boss else [40, 36, 43, 38]
	if is_boss:
		melody = [52, 55, 56, 55, 52, 51, 48, 51, 52, 55, 59, 56, 55, 52, 51, 47,
			48, 51, 55, 56, 55, 51, 48, 44, 47, 50, 53, 56, 55, 53, 50, 47]
	for index in range(sample_count):
		var time := float(index) / SPELL_SAMPLE_RATE
		var step := int(time / 0.25) % melody.size()
		var step_phase := fmod(time, 0.25) / 0.25
		var melody_frequency := _midi_frequency(melody[step] + (0 if is_boss else 12))
		var lead_envelope := pow(1.0 - step_phase, 1.6)
		var lead := (sin(TAU * melody_frequency * time) + sin(TAU * melody_frequency * 2.0 * time) * 0.22) * lead_envelope * 0.23
		var bass_frequency := _midi_frequency(bass_roots[(step / 8) % bass_roots.size()])
		var bass := (sin(TAU * bass_frequency * time) + sin(TAU * bass_frequency * 2.0 * time) * 0.16) * 0.24
		var beat_phase := fmod(time, 0.5) / 0.5
		var kick := sin(TAU * (72.0 - beat_phase * 30.0) * time) * pow(1.0 - beat_phase, 8.0) * 0.30
		var eighth_phase := fmod(time, 0.25) / 0.25
		var hat_wave := sin(TAU * 6200.0 * time) * sin(TAU * 3791.0 * time)
		var hat := hat_wave * pow(1.0 - eighth_phase, 14.0) * 0.055
		var sample_value := clampi(roundi((lead + bass + kick + hat) * 32767.0), -32768, 32767)
		bytes[index * 2] = sample_value & 0xff
		bytes[index * 2 + 1] = (sample_value >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SPELL_SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream


func _midi_frequency(note: int) -> float:
	return 440.0 * pow(2.0, (float(note) - 69.0) / 12.0)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _apply_settings() -> void:
	set_master_volume(SettingsManager.master_volume)
	set_music_volume(SettingsManager.music_volume)
	set_sfx_volume(SettingsManager.sfx_volume)


func shutdown() -> void:
	if _music_player != null:
		_music_player.stop()
		_music_player.stream = null
	_music_cache.clear()
	_spell_sound_cache.clear()


func _exit_tree() -> void:
	shutdown()
