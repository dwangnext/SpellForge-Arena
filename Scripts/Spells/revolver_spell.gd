class_name RevolverSpell
extends Spell

const BULLET_SCENE := preload("res://Scenes/Spells/ProjectileSpell.tscn")

var _shots_remaining := 0
var _shot_timer := 0.0
var _muzzle_flash := 0.0


func activate() -> void:
	super.activate()
	_shots_remaining = definition.burst_count
	_fire_shot()


func _physics_process(delta: float) -> void:
	_muzzle_flash = maxf(_muzzle_flash - delta, 0.0)
	_shot_timer -= delta
	if _shots_remaining > 0 and _shot_timer <= 0.0:
		_fire_shot()
	queue_redraw()
	if _shots_remaining <= 0 and _muzzle_flash <= 0.0:
		finish()


func _fire_shot() -> void:
	_shots_remaining -= 1
	_shot_timer = definition.burst_interval
	_muzzle_flash = 0.055
	var pellet_count := maxi(definition.pellets_per_shot + modifiers.extra_projectiles, 1)
	for pellet_index in range(pellet_count):
		var fraction := 0.5 if pellet_count == 1 else float(pellet_index) / (pellet_count - 1)
		var spread := deg_to_rad(lerpf(-definition.spread_degrees * 0.5, definition.spread_degrees * 0.5, fraction))
		var bullet := BULLET_SCENE.instantiate() as ProjectileSpell
		var bullet_target := global_position + direction.rotated(spread) * definition.cast_range
		bullet.configure(definition, caster, global_position + direction * 30.0, bullet_target, modifiers.duplicate_snapshot())
		bullet.sound_enabled = false
		get_parent().add_child(bullet)
		bullet.activate()
	AudioManager.play_spell_sfx(global_position, definition.sound_pitch_hz + randf_range(-18.0, 18.0), definition.sound_duration)
	CameraEffects.shake(1.2 + definition.damage * 0.025, 0.06)


func _draw() -> void:
	if definition == null or _muzzle_flash <= 0.0:
		return
	var flash_color := definition.secondary_color
	flash_color.a = clampf(_muzzle_flash / 0.055, 0.0, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(24, 0), Vector2(44, -10), Vector2(38, 0), Vector2(44, 10)]), flash_color)
	draw_circle(Vector2(27, 0), 7.0, Color(definition.primary_color, flash_color.a))
