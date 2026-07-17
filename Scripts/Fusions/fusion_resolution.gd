class_name FusionResolution
extends RefCounted

var spell: SpellDefinition
var modifiers: SpellModifiers
var recipe: FusionRecipe


func _init(resolved_spell: SpellDefinition, resolved_modifiers: SpellModifiers, fusion_recipe: FusionRecipe = null) -> void:
	spell = resolved_spell
	modifiers = resolved_modifiers
	recipe = fusion_recipe
