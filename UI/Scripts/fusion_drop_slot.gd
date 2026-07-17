class_name FusionDropSlot
extends PanelContainer

signal spell_dropped(spell: SpellDefinition)

@export var placeholder := "DROP SPELL HERE"

var spell: SpellDefinition
var _label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(280, 115)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)
	_refresh()


func set_spell(definition: SpellDefinition) -> void:
	spell = definition
	_refresh()


func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is SpellDefinition


func _drop_data(_at_position: Vector2, data) -> void:
	set_spell(data as SpellDefinition)
	spell_dropped.emit(spell)


func _refresh() -> void:
	if _label == null:
		return
	_label.text = placeholder if spell == null else "%s\n%s" % [spell.display_name, "OWNED" if MetaProgression.is_spell_unlocked(spell.id) else "LOCKED"]
	_label.add_theme_color_override("font_color", Color("9da8c7") if spell == null else spell.primary_color.lightened(0.2))
