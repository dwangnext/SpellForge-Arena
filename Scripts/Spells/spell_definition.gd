class_name SpellDefinition
extends Resource

enum VisualStyle { FIRE, ICE, LIGHTNING, ARCANE, WIND, POISON, LASER, METEOR, RAPID, SHIELD }

@export_category("Identity")
@export var id := "spell"
@export var display_name := "Spell"
@export_multiline var description := ""
@export var spell_scene: PackedScene
@export var visual_style := VisualStyle.ARCANE
@export var primary_color := Color("8e7dff")
@export var secondary_color := Color.WHITE
@export var unlocked_by_default := true
@export_range(0, 1000000, 1) var unlock_cost := 0
@export_enum("wand", "revolver", "gauntlet", "spawner") var weapon_id := "wand"
@export var fusion_eligible := true

@export_category("Core Statistics")
@export_range(0.0, 10000.0, 1.0) var damage := 20.0
@export_range(0.05, 60.0, 0.05) var cooldown := 1.0
@export_range(1.0, 5000.0, 10.0) var cast_range := 700.0
@export_range(0.0, 3000.0, 10.0) var speed := 500.0
@export_range(0.0, 1000.0, 5.0) var area_radius := 0.0
@export_range(0.0, 3000.0, 10.0) var knockback_force := 160.0

@export_category("Behavior")
@export_range(0.01, 30.0, 0.01) var duration := 1.0
@export_range(0.02, 5.0, 0.02) var tick_interval := 0.25
@export_range(0, 100, 1) var pierce_count := 0
@export var homing := false
@export_range(0.0, 20.0, 0.1) var homing_strength := 5.0
@export_range(1.0, 300.0, 1.0) var line_width := 24.0
@export_range(0.0, 10.0, 0.05) var impact_delay := 0.0

@export_category("Intrinsic Status")
@export_enum("none", "freeze", "burn", "poison", "stun") var intrinsic_status := "none"
@export_range(0.0, 1.0, 0.01) var intrinsic_status_chance := 0.0
@export_range(0.0, 20.0, 0.05) var intrinsic_status_duration := 0.0
@export_range(0.0, 1000.0, 1.0) var intrinsic_status_damage := 0.0

@export_category("Ballistic Pattern")
@export_range(1, 24, 1) var burst_count := 1
@export_range(0.01, 1.0, 0.01) var burst_interval := 0.09
@export_range(1, 16, 1) var pellets_per_shot := 1
@export_range(0.0, 120.0, 1.0) var spread_degrees := 0.0

@export_category("Audio")
@export_range(50.0, 2000.0, 1.0) var sound_pitch_hz := 440.0
@export_range(0.05, 1.0, 0.01) var sound_duration := 0.18


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.strip_edges().is_empty():
		errors.append("ID is required.")
	if display_name.strip_edges().is_empty():
		errors.append("Display name is required.")
	if spell_scene == null:
		errors.append("Spell scene is required.")
	if damage < 0.0:
		errors.append("Damage cannot be negative.")
	if cooldown <= 0.0:
		errors.append("Cooldown must be greater than zero.")
	if cast_range <= 0.0:
		errors.append("Range must be greater than zero.")
	if speed < 0.0:
		errors.append("Speed cannot be negative.")
	if not weapon_id in ["wand", "revolver", "gauntlet", "spawner"]:
		errors.append("Weapon ID must be wand, revolver, gauntlet, or spawner.")
	return errors
