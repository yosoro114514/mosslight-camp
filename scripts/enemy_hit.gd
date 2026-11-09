extends Node2D

enum Style { PHYSICAL, MAGIC, BLOCK }
const GOLD := Color("#ffb64b")
const VIOLET := Color("#d197ff")
const STEEL := Color("#bce5fa")
const FONT = preload("res://art/camp-type.otf")
const TEXT_TIME := 0.74
const LANES := [Vector2(17,0), Vector2(-18,-4), Vector2(0,-18)]

var target
var style: Style
var direction: Vector2
var strength: float
var body_offset: Vector2
var lethal: bool
var age: float
var duration: float
var caption: String
var caption_width: float
var caption_anchor: Vector2
var lane: Vector2

func start(enemy, appearance: Style, incoming: Vector2, weight: float, delay: float, killed: bool, lost_hp: float) -> void:
	target = enemy
	style = appearance
	direction = incoming.normalized() if not incoming.is_zero_approx() else Vector2.RIGHT
	strength = weight
	lethal = killed
	age = -delay
	duration = 0.36 if killed else 0.22
	caption = "格挡" if style == Style.BLOCK else "-" + ("%.2f" % lost_hp).rstrip("0").rstrip(".")
	caption_width = FONT.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	lane = LANES[enemy.next_hit_lane]
	var size: float = enemy.profile.sprite_size
	body_offset = Vector2(0, 8.0 - size*0.5 - enemy.profile.lift)
	position = enemy.position + body_offset
	enemy.get_parent().add_child(self)
	if delay <= 0:
		react()

func react() -> void:
	caption_anchor = position + lane + Vector2(0,-12)
	if not lethal and is_instance_valid(target) and not target.is_destroyed:
		target.show_hit(style, direction, strength)

func _process(delta: float) -> void:
	if is_instance_valid(target) and not target.is_destroyed:
		position = target.position + body_offset
	var pending := age < 0
	age += delta
	if pending and age >= 0:
		react()
	if age >= TEXT_TIME:
		queue_free()
	queue_redraw()

func _draw() -> void:
	if age < 0 or age >= TEXT_TIME:
		return
	if age < duration:
		draw_impact()
	var t := age / TEXT_TIME
	var lift := 27.0 * (1.0 - pow(1.0-t,2))
	var baseline := caption_anchor + Vector2(lane.x*t*0.55,-lift)
	# On the top road, letters travel down from the HUD edge into the board.
	if caption_anchor.y < 224:
		baseline.y = maxf(196,caption_anchor.y) + lift
	baseline.x = clampf(baseline.x,caption_width*0.5+3,597-caption_width*0.5)
	var origin := baseline - position - Vector2(caption_width*0.5,0)
	var ink: Color = [GOLD,VIOLET,STEEL][style]
	var opacity := 1.0 - smoothstep(0.60,1.0,t)
	draw_string_outline(FONT,origin,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18,4,Color(Color("#302534"),opacity))
	draw_string(FONT,origin,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(ink,opacity))

func draw_impact() -> void:
	var t := age / duration
	var fade := 1.0 - t
	var span := (12.0 + strength*7.0 + (7 if lethal else 0)) * (0.32 + 0.68*sin(t*PI/2))
	match style:
		Style.PHYSICAL:
			var across := direction.rotated(0.78)
			draw_line(-across*span*0.65,across*span,Color("#743e2d",fade),4.5*fade+1,true)
			draw_line(-across*span*0.65,across*span,Color("#fff4c7",fade),2.3*fade+0.5,true)
			for i in (7 if lethal else 4):
				var ray := direction.rotated((i-1.5)*1.21)
				draw_line(ray*span*(0.18+t*0.8),ray*span*1.22,Color(GOLD,fade),1.0+2*fade,true)
		Style.MAGIC:
			draw_arc(Vector2.ZERO,span,0,TAU,32,Color(VIOLET,fade),1.0+2*fade,true)
			for i in (6 if lethal else 4):
				var ray := direction.rotated(i*TAU/(6 if lethal else 4)+t*0.72)
				var center := ray*span
				var long_axis := ray*(2.0+3.5*fade)
				var side := ray.orthogonal()*(1.0+1.8*fade)
				draw_colored_polygon(PackedVector2Array([center-long_axis,center+side,center+long_axis,center-side]),Color("#f4eaff",fade))
		Style.BLOCK:
			var angle := (-direction).angle()
			draw_arc(Vector2.ZERO,12+4*t,angle-0.95,angle+0.95,16,Color("#496d85",fade),5,true)
			draw_arc(Vector2.ZERO,12+4*t,angle-0.86,angle+0.86,16,Color(STEEL,fade),2,true)
			for side in [-1,1]:
				var ray := (-direction).rotated(0.68*side)
				draw_line(ray*(15+5*t),ray*(19+9*t),Color(STEEL,fade),1.6,true)
