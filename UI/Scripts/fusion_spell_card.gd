class_name FusionSpellCard
extends Button

var spell: SpellDefinition


func configure(definition: SpellDefinition) -> void:
	spell = definition
	custom_minimum_size = Vector2(250, 54)
	text = "%s  —  %s" % [spell.display_name, "OWNED" if MetaProgression.is_spell_unlocked(spell.id) else "LOCKED"]
	tooltip_text = spell.description
	add_theme_color_override("font_color", spell.primary_color.lightened(0.2))


func _get_drag_data(_at_position: Vector2):
	if spell == null:
		return null
	var preview := Label.new()
	preview.text = spell.display_name
	preview.add_theme_color_override("font_color", spell.primary_color.lightened(0.25))
	set_drag_preview(preview)
	return spell
