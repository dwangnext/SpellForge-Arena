class_name ChronoLockField
extends Spell

const LOCK_DURATION := 2.0
const DAMAGE_INTERVAL := 0.25

var _target: Area2D
var _elapsed := 0.0
var _damage_remaining := 0.0


func bind_target(target: Area2D) -> void:
	_target = target


func activate() -> void:
	sound_enabled = false
	super.activate()
	_damage_remaining = 0.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_damage_remaining -= delta
	if not is_instance_valid(_target) or _target.is_queued_for_deletion():
		finish()
		return
	global_position = _target.global_position
	global_rotation = 0.0
	if _damage_remaining <= 0.0:
		_damage_remaining += DAMAGE_INTERVAL
		damage_hurtbox(_target, 0.13, Vector2.ZERO)
		AudioManager.play_spell_sfx(global_position, 1180.0 + sin(_elapsed * 17.0) * 120.0, 0.045)
	queue_redraw()
	if _elapsed >= LOCK_DURATION:
		CameraEffects.flash(Color("76dfff"), 0.08, 0.09)
		finish()


func _draw() -> void:
	var pulse := 1.0 + sin(_elapsed * 14.0) * 0.08
	var spin := _elapsed * 5.5
	draw_circle(Vector2.ZERO, 35.0 * pulse, Color(0.18, 0.55, 1.0, 0.09))
	draw_arc(Vector2.ZERO, 31.0 * pulse, spin, spin + 4.9, 36, Color("80edff"), 3.0, true)
	draw_arc(Vector2.ZERO, 23.0, -spin * 1.3, -spin * 1.3 + 4.4, 30, Color("ffe260"), 2.5, true)
	for index in range(3):
		var angle := spin + TAU * float(index) / 3.0
		var rune_position := Vector2.RIGHT.rotated(angle) * 42.0
		draw_circle(rune_position, 7.0, Color("ffe260"))
		draw_circle(rune_position, 3.0, Color.WHITE)
		var zig := PackedVector2Array([rune_position, rune_position * 0.62 + Vector2(-5, 4).rotated(angle), Vector2.RIGHT.rotated(angle + 0.7) * 13.0, Vector2.ZERO])
		draw_polyline(zig, Color("79eaff"), 2.5, true)
	draw_line(Vector2(-13, 0), Vector2(13, 0), Color("d9fbff"), 2.0, true)
	draw_line(Vector2(0, -13), Vector2(0, 13), Color("d9fbff"), 2.0, true)
