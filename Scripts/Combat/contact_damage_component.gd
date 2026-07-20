class_name ContactDamageComponent
extends Area2D

@export_range(0.1, 5.0, 0.05) var damage_interval := 0.8

var _target_cooldowns: Dictionary = {}


func _physics_process(delta: float) -> void:
	for target_id in _target_cooldowns.keys():
		var remaining := float(_target_cooldowns[target_id]) - delta
		if remaining <= 0.0:
			_target_cooldowns.erase(target_id)
		else:
			_target_cooldowns[target_id] = remaining
	for body in get_overlapping_bodies():
		_try_damage(body)


func _try_damage(body: Node) -> void:
	if not body.has_method("apply_damage"):
		return
	var target_id := body.get_instance_id()
	if float(_target_cooldowns.get(target_id, 0.0)) > 0.0:
		return
	_target_cooldowns[target_id] = damage_interval
	body.apply_damage(float(get_meta("damage", 10.0)))
