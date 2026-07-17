class_name HurtboxComponent
extends Area2D

signal hit_received(payload: DamagePayload)

@export var receiver_path: NodePath = NodePath("..")


func receive_hit(payload: DamagePayload) -> void:
	var receiver := get_node_or_null(receiver_path)
	if receiver != null and receiver.has_method("receive_hit"):
		receiver.receive_hit(payload)
		hit_received.emit(payload)
