# Adapted from exeldee's enemy_mover.gd, MIT (LICENSE-template.txt).
extends PathFollow2D

signal resolved(leaked: bool)
enum Kind { MUSHROOM, MOTH, TURTLE, BEETLE, SLIME }
enum DamageType { PHYSICAL, MAGIC }
const DEFENSE := {Kind.MUSHROOM: 0, Kind.MOTH: 0, Kind.TURTLE: 1, Kind.BEETLE: 1, Kind.SLIME: 0}
const MAGIC_RESIST_PERCENT := {Kind.MUSHROOM: 0, Kind.MOTH: 25, Kind.TURTLE: -20, Kind.BEETLE: 0, Kind.SLIME: 35}
const FONT = preload("res://art/camp-type.otf")
const TEXTURES = [preload("res://art/gremlin.png"), preload("res://art/moth.png"), preload("res://art/turtle.png"), preload("res://art/beetle.png"), preload("res://art/slime.png")]
const SIZES := [46.0, 43.0, 58.0, 48.0, 47.0]
const BODY_RADIUS := 16.0

var hp := 4.0
var kind := Kind.MUSHROOM
var is_boss := false
var frost_remaining := 0.0
var entry_guard := 0.0
var max_hp := 4
var speed := 94.0
var is_destroyed := false
var flash := 0.0
var blade_contacts := {}
var previous_position := Vector2.ZERO
var ability_clock := 0.0
var heal_flash := 0.0
var has_blocked := false
var block_notice := 0.0

func _ready() -> void:
	process_physics_priority = -1
	previous_position = position
	add_to_group("enemy")

func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
	previous_position = position
	var chilled_time := minf(frost_remaining, delta)
	ability_clock += delta
	heal_flash = maxf(0, heal_flash - delta)
	block_notice = maxf(0, block_notice - delta)
	var dash := kind == Kind.BEETLE and fmod(ability_clock, 3.0) >= 2.25
	var pace := speed * (1.95 if dash else 1.0) * (1.0 + 0.5 * entry_reduction())
	progress += pace * (delta - 0.4 * chilled_time)
	frost_remaining -= chilled_time
	if kind == Kind.SLIME and ability_clock >= 2.4:
		ability_clock -= 2.4
		if hp < max_hp:
			hp = minf(max_hp, hp + maxi(1, ceili(max_hp * 0.10)))
			heal_flash = 0.4
	if progress_ratio >= 0.99999:
		finished_path()
		return
	flash = maxf(0.0, flash - delta)
	queue_redraw()

func finished_path() -> void:
	resolve(true)

func entry_reduction() -> float:
	if entry_guard == 0.0:
		return 0.0
	return entry_guard * maxf(0.0, 1.0 - progress_ratio / 0.35)

func get_damage(attack: int, damage_type: DamageType) -> void:
	if is_destroyed:
		return
	var damage: float
	if damage_type == DamageType.PHYSICAL:
		var defense: int = 2 if is_boss else DEFENSE[kind]
		damage = maxi(0, attack - defense)
		if damage == 0:
			if not has_blocked:
				has_blocked = true
				block_notice = 0.8
			return
	else:
		damage = attack * (100 - int(MAGIC_RESIST_PERCENT[kind])) / 100.0
	# Apply entry protection after armor and resistance.
	damage *= 1.0 - entry_reduction()
	hp = snappedf(maxf(0, hp - damage), 0.01)
	flash = 0.13
	if hp <= 0:
		resolve(false)

func resolve(leaked: bool) -> void:
	if is_destroyed:
		return
	is_destroyed = true
	resolved.emit(leaked)
	queue_free()

func _draw() -> void:
	var bob := absf(sin(progress * 0.081)) * 3.4
	var size: float = 78.0 if is_boss else SIZES[kind]
	var lift := 5.0 if kind == Kind.MOTH else 0.0
	var guard := entry_reduction()
	if guard > 0.0:
		var center := Vector2(0, -size * 0.28 - bob - lift)
		var radius := size * 0.54
		draw_circle(center, radius, Color(1.0, 0.77, 0.27, 0.18 * guard), true, -1, true)
		draw_arc(center, radius, -PI/2, -PI/2 + TAU * guard, 36, Color(1.0, 0.86, 0.43, 0.9), 3.0, true)
	var tint := Color("#99e7ff") if frost_remaining > 0 else Color.WHITE
	if flash > 0:
		tint = Color(1.5, 1.25, 1.1)
	draw_set_transform(Vector2(0, 5), 0, Vector2(1, 0.31))
	draw_circle(Vector2.ZERO, size * 0.45, Color("#302f3e55"))
	if is_boss:
		draw_arc(Vector2.ZERO, 34, 0, TAU, 48, Color("#ffda73"), 4, true)
	draw_set_transform(Vector2.ZERO)
	if kind == Kind.BEETLE and fmod(ability_clock, 3.0) >= 2.25:
		var back := (previous_position-position).normalized()
		for offset in [-4, 4]:
			var point: Vector2 = back*16 + back.orthogonal()*offset
			draw_line(point,point+back*13,Color("#ffe1a1"),2,true)
	draw_texture_rect(TEXTURES[kind], Rect2(-size/2, 11-size-bob-lift, size, size), false, tint)
	if heal_flash > 0:
		var cross := Vector2(16,-31-10*(1-heal_flash/0.4))
		draw_line(cross-Vector2(4,0),cross+Vector2(4,0),Color("#a5ffb9"),3,true)
		draw_line(cross-Vector2(0,4),cross+Vector2(0,4),Color("#a5ffb9"),3,true)
	if frost_remaining > 0:
		draw_arc(Vector2(0,5),18,0,TAU,24,Color("#97ecff"),2,true)
	if block_notice > 0:
		var notice_pos := Vector2(10, maxf(-25.0 - (0.8 - block_notice) * 12, 195.0 - global_position.y))
		draw_string_outline(FONT, notice_pos, "格挡", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color("#342638"))
		draw_string(FONT, notice_pos, "格挡", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ffdf93"))
	if is_boss:
		var crown := PackedVector2Array([Vector2(-10,-4),Vector2(-5,0),Vector2(0,-8),Vector2(5,0),Vector2(10,-4),Vector2(7,5),Vector2(-7,5)])
		draw_set_transform(Vector2(1,-40-bob))
		draw_colored_polygon(crown,Color("#ffda70"))
		crown.append(crown[0])
		draw_polyline(crown,Color("#80502e"),1.8,true)
		draw_set_transform(Vector2.ZERO)
		return
	var label_pos := Vector2(-22, 17-size-bob-lift)
	# Leave room below the deployment controls on the upper stretch of road.
	label_pos.y = maxf(label_pos.y, 195.0 - global_position.y)
	var health_text := str(ceili(hp))
	draw_string_outline(ThemeDB.fallback_font, label_pos, health_text, HORIZONTAL_ALIGNMENT_CENTER, 44, 17, 5, Color("#342638"))
	draw_string(ThemeDB.fallback_font, label_pos, health_text, HORIZONTAL_ALIGNMENT_CENTER, 44, 17, Color("#fff4cd"))
