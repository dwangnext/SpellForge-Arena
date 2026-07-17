class_name CharacterDefinition
extends Resource

@export var id := "character"
@export var display_name := "Character"
@export_multiline var description := ""
@export var unlocked_by_default := false
@export_range(0, 1000000, 1) var unlock_cost := 100
@export_range(0.1, 5.0, 0.01) var health_multiplier := 1.0
@export_range(0.1, 5.0, 0.01) var movement_multiplier := 1.0
@export_range(0.1, 5.0, 0.01) var damage_multiplier := 1.0
@export_range(0.1, 5.0, 0.01) var cooldown_multiplier := 1.0
@export var color := Color("6f63d9")
