extends Resource

@export var display_name: String
@export var portrait: Texture2D
@export var guide_note: String
@export var sprite_size := 46.0
@export var lift := 0.0

@export_group("Combat")
@export_range(0, 100, 1, "or_greater") var defense := 0
@export_range(-100, 100, 1, "or_less", "suffix:%") var magic_resist_percent := 0
@export_range(0.01, 10.0, 0.01, "or_greater") var hp_multiplier := 1.0
@export_range(0.01, 10.0, 0.01, "or_greater") var speed_multiplier := 1.0

@export_group("Dash")
@export var dash_period := 0.0
@export var dash_duration := 0.0
@export var dash_speed_multiplier := 1.0

@export_group("Regeneration")
@export var heal_period := 0.0
@export_range(0, 100, 1, "suffix:%") var heal_percent := 0

@export_group("Boss")
@export var boss_base_hp := 0
@export var boss_speed := 0.0

func defenses_text() -> String:
	return "防御 %d · 法抗 %d%%" % [defense, magic_resist_percent]
