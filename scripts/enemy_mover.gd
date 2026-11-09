# Adapted from exeldee's enemy_mover.gd, MIT (LICENSE-template.txt).
extends PathFollow2D

signal resolved(leaked: bool)
enum Kind { MUSHROOM, MOTH, TURTLE, BEETLE, SLIME }
enum DamageType { PHYSICAL, MAGIC }
const HitFX = preload("res://scripts/enemy_hit.gd")
const Profile = preload("res://scripts/enemy_profile.gd")
const BODY_RADIUS := 16.0

static var profiles: Dictionary[int, Profile] = {
	Kind.MUSHROOM: load("res://data/enemies/mushroom.tres"),
	Kind.MOTH: load("res://data/enemies/moth.tres"),
	Kind.TURTLE: load("res://data/enemies/turtle.tres"),
	Kind.BEETLE: load("res://data/enemies/beetle.tres"),
	Kind.SLIME: load("res://data/enemies/slime.tres")
}
static var boss_profile: Profile = load("res://data/enemies/boss_turtle.tres")

var hp := 4.0
var kind := Kind.MUSHROOM
var is_boss := false
var profile: Profile:
	get:
		return boss_profile if is_boss else profiles[kind]
var frost_remaining := 0.0
var entry_guard := 0.0
var max_hp := 4
var speed := 94.0
var is_destroyed := false
var flash := 0.0
var hit_direction := Vector2.ZERO
var hit_strength := 0.0
var hit_style := HitFX.Style.PHYSICAL
var blade_contacts := {}
var previous_position := Vector2.ZERO
var ability_clock := 0.0
var last_heal_tick := 0
var heal_flash := 0.0
var next_hit_lane := 0

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
	var pace := speed * (profile.dash_speed_multiplier if is_dashing() else 1.0) * (1.0 + 0.5 * entry_reduction())
	progress += pace * (delta - 0.4 * chilled_time)
	frost_remaining -= chilled_time
	if profile.heal_period > 0 and profile.heal_percent > 0:
		var tick := floori(ability_clock / profile.heal_period)
		if tick > last_heal_tick and hp < max_hp:
			hp = minf(max_hp, hp + (tick - last_heal_tick) * ceili(max_hp * (profile.heal_percent / 100.0)))
			heal_flash = 0.4
		last_heal_tick = tick
	if progress_ratio >= 0.99999:
		finished_path()
		return
	flash = maxf(0.0, flash - delta)
	queue_redraw()

func finished_path() -> void:
	resolve(true)

func is_dashing() -> bool:
	return profile.dash_period > 0 and fmod(ability_clock, profile.dash_period) >= profile.dash_period - profile.dash_duration

func entry_reduction() -> float:
	if entry_guard == 0.0:
		return 0.0
	return entry_guard * maxf(0.0, 1.0 - progress_ratio / 0.35)

func get_damage(attack: int, damage_type: DamageType, incoming := Vector2.RIGHT, visual_delay := 0.0) -> void:
	if is_destroyed:
		return
	var damage: float
	if damage_type == DamageType.PHYSICAL:
		damage = maxi(0, attack - profile.defense)
	else:
		damage = attack * (100 - profile.magic_resist_percent) / 100.0
	# Apply entry protection after armor and resistance.
	damage *= 1.0 - entry_reduction()
	var previous_hp := hp
	hp = snappedf(maxf(0, hp - damage), 0.01)
	var lost_hp := snappedf(previous_hp - hp, 0.01)
	var style := HitFX.Style.PHYSICAL if damage_type == DamageType.PHYSICAL else HitFX.Style.MAGIC
	if lost_hp == 0:
		style = HitFX.Style.BLOCK
	var weight := clampf(damage / maxf(1,max_hp) * 3.0, 0.22, 1.0)
	if get_parent() != null:
		HitFX.new().start(self, style, incoming, weight, visual_delay, hp <= 0, lost_hp)
		next_hit_lane = (next_hit_lane + 1) % HitFX.LANES.size()
	else:
		show_hit(style, incoming.normalized(), weight)
	if hp <= 0:
		resolve(false)

func show_hit(style: HitFX.Style, direction: Vector2, strength: float) -> void:
	hit_style = style
	hit_direction = direction
	hit_strength = strength
	flash = 0.16
	queue_redraw()

func resolve(leaked: bool) -> void:
	if is_destroyed:
		return
	is_destroyed = true
	resolved.emit(leaked)
	queue_free()

func _draw() -> void:
	var bob := absf(sin(progress * 0.081)) * 3.4
	var size := profile.sprite_size
	var lift := profile.lift
	var guard := entry_reduction()
	if guard > 0.0:
		var center := Vector2(0, -size * 0.28 - bob - lift)
		var radius := size * 0.54
		draw_circle(center, radius, Color(1.0, 0.77, 0.27, 0.18 * guard), true, -1, true)
		draw_arc(center, radius, -PI/2, -PI/2 + TAU * guard, 36, Color(1.0, 0.86, 0.43, 0.9), 3.0, true)
	var tint := Color("#99e7ff") if frost_remaining > 0 else Color.WHITE
	var recoil := Vector2.ZERO
	var squash := 0.0
	if flash > 0:
		var pulse := flash / 0.16
		var accent := Color(1.55,1.32,1.08)
		if hit_style == HitFX.Style.MAGIC:
			accent = Color(1.35,1.12,1.6)
		elif hit_style == HitFX.Style.BLOCK:
			accent = Color(1.04,1.14,1.22)
		tint = tint.lerp(accent,pulse)
		recoil = hit_direction * (1.5 + 4.0*hit_strength) * pulse * (0.6 if is_boss else 1.0)
		squash = 0.09 * hit_strength * pulse
	draw_set_transform(Vector2(0, 5), 0, Vector2(1, 0.31))
	draw_circle(Vector2.ZERO, size * 0.45, Color("#302f3e55"))
	if is_boss:
		draw_arc(Vector2.ZERO, 34, 0, TAU, 48, Color("#ffda73"), 4, true)
	draw_set_transform(Vector2.ZERO)
	if is_dashing():
		var back := (previous_position-position).normalized()
		for offset in [-4, 4]:
			var point: Vector2 = back*16 + back.orthogonal()*offset
			draw_line(point,point+back*13,Color("#ffe1a1"),2,true)
	var feet := Vector2(0,11-bob-lift)
	draw_set_transform(feet+recoil,hit_direction.x*squash,Vector2(1+squash,1-squash))
	draw_texture_rect(profile.portrait, Rect2(-size/2,-size,size,size), false, tint)
	draw_set_transform(Vector2.ZERO)
	if heal_flash > 0:
		var cross := Vector2(16,-31-10*(1-heal_flash/0.4))
		draw_line(cross-Vector2(4,0),cross+Vector2(4,0),Color("#a5ffb9"),3,true)
		draw_line(cross-Vector2(0,4),cross+Vector2(0,4),Color("#a5ffb9"),3,true)
	if frost_remaining > 0:
		draw_arc(Vector2(0,5),18,0,TAU,24,Color("#97ecff"),2,true)
	if is_boss:
		draw_crown(self, Vector2(1,-40-bob)+recoil, hit_direction.x*squash)
		return
	var label_pos := Vector2(-22, 17-size-bob-lift)
	# Leave room below the deployment controls on the upper stretch of road.
	label_pos.y = maxf(label_pos.y, 195.0 - global_position.y)
	var health_text := str(ceili(hp))
	draw_string_outline(ThemeDB.fallback_font, label_pos, health_text, HORIZONTAL_ALIGNMENT_CENTER, 44, 17, 5, Color("#342638"))
	draw_string(ThemeDB.fallback_font, label_pos, health_text, HORIZONTAL_ALIGNMENT_CENTER, 44, 17, Color("#fff4cd"))

static func draw_crown(canvas: CanvasItem, center: Vector2, tilt := 0.0) -> void:
	var crown := PackedVector2Array([Vector2(-10,-4),Vector2(-5,0),Vector2(0,-8),Vector2(5,0),Vector2(10,-4),Vector2(7,5),Vector2(-7,5)])
	canvas.draw_set_transform(center, tilt)
	canvas.draw_colored_polygon(crown,Color("#ffda70"))
	crown.append(crown[0])
	canvas.draw_polyline(crown,Color("#80502e"),1.8,true)
	canvas.draw_set_transform(Vector2.ZERO)
