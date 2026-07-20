class_name SpawnerStructureSpell
extends Spell


func activate() -> void:
	super.activate()
	if NetworkManager.is_world_authority():
		var structure := SpawnerStructure.new()
		structure.configure(definition.id, definition.display_name, target_position, definition.primary_color)
		get_parent().add_child(structure)
	finish()


func _draw() -> void:
	if definition == null:
		return
	draw_circle(Vector2.ZERO, 16.0, Color(definition.primary_color, 0.25))
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 24, definition.primary_color, 3.0, true)
