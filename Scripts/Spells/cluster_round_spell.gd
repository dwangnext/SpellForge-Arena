class_name ClusterRoundSpell
extends Spell

const PROJECTILE_SCENE := preload("res://Scenes/Spells/ProjectileSpell.tscn")

@onready var hitbox: Area2D = $Hitbox

var _distance_traveled := 0.0
var _split_distance := 0.0
var _side_shot_remaining := 0.0
var _finished := false


func activate() -> void:
	super.activate()
	_split_distance = get_cast_range() * clampf(definition.impact_delay, 0.25, 0.9)
	_side_shot_remaining = definition.tick_interval
	hitbox.area_entered.connect(_on_area_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _finished:
		return
	var movement := direction * get_speed() * delta
	global_position += movement
	_distance_traveled += movement.length()
	_side_shot_remaining -= delta
	if definition.pellets_per_shot > 1 and _side_shot_remaining <= 0.0:
		_side_shot_remaining = definition.tick_interval
		_emit_side_rounds()
	rotation = direction.angle()
	queue_redraw()
	if _distance_traveled >= _split_distance:
		_split_into_shards()


func _on_area_entered(area: Area2D) -> void:
	if _finished or not area.has_method("receive_hit"):
		return
	damage_hurtbox(area, 1.0, direction)
	_split_into_shards()


func _split_into_shards() -> void:
	if _finished:
		return
	_finished = true
	var shard_count := maxi(definition.burst_count, 3)
	for shard_index in range(shard_count):
		var fraction := 0.5 if shard_count == 1 else float(shard_index) / (shard_count - 1)
		var angle := deg_to_rad(lerpf(-definition.spread_degrees * 0.5, definition.spread_degrees * 0.5, fraction))
		_spawn_shard(direction.rotated(angle), 0.34, definition.cast_range * 0.58)
	VFXManager.spawn_death(get_parent(), global_position, definition.primary_color)
	AudioManager.play_spell_sfx(global_position, definition.sound_pitch_hz * 1.45, 0.18)
	CameraEffects.shake(5.0, 0.14)
	finish()


func _emit_side_rounds() -> void:
	var pairs := maxi(definition.pellets_per_shot - 1, 1)
	for pair in range(pairs):
		var tilt := deg_to_rad(62.0 + pair * 14.0)
		_spawn_shard(direction.rotated(tilt), 0.18, 360.0)
		_spawn_shard(direction.rotated(-tilt), 0.18, 360.0)


func _spawn_shard(shard_direction: Vector2, damage_multiplier: float, shard_range: float) -> void:
	var shard_definition := definition.duplicate(true) as SpellDefinition
	shard_definition.damage = definition.damage * damage_multiplier
	shard_definition.area_radius = 0.0
	shard_definition.cast_range = shard_range
	shard_definition.speed = definition.speed * 1.35
	shard_definition.burst_count = 1
	shard_definition.pellets_per_shot = 1
	var shard := PROJECTILE_SCENE.instantiate() as ProjectileSpell
	shard.configure(shard_definition, caster, global_position, global_position + shard_direction * shard_range, modifiers.duplicate_snapshot())
	shard.sound_enabled = false
	get_parent().add_child(shard)
	shard.activate()


func _draw() -> void:
	if definition == null:
		return
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.018) * 0.12
	draw_circle(Vector2.ZERO, 24.0 * pulse, Color(definition.primary_color, 0.28))
	draw_circle(Vector2.ZERO, 15.0 * pulse, definition.primary_color)
	draw_arc(Vector2.ZERO, 29.0, 0.0, TAU, 24, definition.secondary_color, 4.0, true)
	for fin in range(4):
		var angle := TAU * fin / 4.0 + Time.get_ticks_msec() * 0.006
		draw_line(Vector2.RIGHT.rotated(angle) * 18.0, Vector2.RIGHT.rotated(angle) * 34.0, definition.secondary_color, 4.0, true)
