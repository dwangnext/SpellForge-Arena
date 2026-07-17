class_name DamagePayload
extends RefCounted

var amount: float
var source: Node
var hit_position: Vector2
var knockback_direction: Vector2
var knockback_force: float
var status_effects: Array[Dictionary] = []


func _init(
	damage_amount: float,
	damage_source: Node,
	position: Vector2,
	direction: Vector2,
	force: float
) -> void:
	amount = damage_amount
	source = damage_source
	hit_position = position
	knockback_direction = direction.normalized()
	knockback_force = maxf(force, 0.0)
