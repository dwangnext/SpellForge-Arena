class_name AchievementDefinition
extends Resource

@export var id := "achievement"
@export var display_name := "Achievement"
@export_multiline var description := ""
@export var statistic_key := "enemies_defeated"
@export_range(1, 100000000, 1) var required_value := 1
@export_range(0, 1000000, 1) var coin_reward := 0
