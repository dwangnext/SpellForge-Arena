class_name PlayerAttackComponent
extends Area2D

signal attack_started
signal attack_finished

@export_range(1.0, 1000.0, 1.0) var base_damage := 25.0
@export_range(0.05, 2.0, 0.01) var attack_cooldown := 0.42
@export_range(0.01, 1.0, 0.01) var active_duration := 0.12
@export_range(0.0, 2000.0, 10.0) var knockback_force := 460.0

var _cooldown_remaining := 0.0
var _active_remaining := 0.0
var _hit_targets: Dictionary = {}
var _is_enabled := true


func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if not _is_enabled:
		return
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if _active_remaining > 0.0:
		_active_remaining = maxf(_active_remaining - delta, 0.0)
		if _active_remaining <= 0.0:
			monitoring = false
			queue_redraw()
			attack_finished.emit()
	if InputManager.is_primary_attack_pressed() and _cooldown_remaining <= 0.0:
		_start_attack()


func _start_attack() -> void:
	_cooldown_remaining = attack_cooldown
	_active_remaining = active_duration
	_hit_targets.clear()
	monitoring = true
	queue_redraw()
	attack_started.emit()
	# Detect targets already overlapping when monitoring is enabled.
	call_deferred("_damage_current_overlaps")


func set_combat_enabled(is_enabled: bool) -> void:
	_is_enabled = is_enabled
	if not is_enabled:
		monitoring = false
		_active_remaining = 0.0
		queue_redraw()


func _damage_current_overlaps() -> void:
	if not monitoring:
		return
	for hurtbox in get_overlapping_areas():
		_on_area_entered(hurtbox)


func _on_area_entered(area: Area2D) -> void:
	if not monitoring or not area.has_method("receive_hit"):
		return
	var target_id := area.get_instance_id()
	if _hit_targets.has(target_id):
		return
	_hit_targets[target_id] = true
	var direction := (area.global_position - global_position).normalized()
	var damage := DamageCalculator.calculate(base_damage)
	var payload := DamagePayload.new(damage, get_parent(), area.global_position, direction, knockback_force)
	area.receive_hit(payload)


func _draw() -> void:
	if not monitoring:
		return
	draw_arc(Vector2(-22, 0), 42.0, -1.05, 1.05, 20, Color(0.45, 0.9, 1.0, 0.72), 7.0, true)
