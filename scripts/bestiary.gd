extends Node2D

const Enemy = preload("res://scripts/enemy_mover.gd")
const OPEN_BUTTON := Rect2(389, 753, 164, 36)
const CLOSE_BUTTON := Rect2(454, 66, 98, 44)

var close_pointer := -2
var previously_paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()

func open() -> void:
	if visible:
		return
	previously_paused = get_tree().paused
	close_pointer = -2
	show()
	get_tree().paused = true

func close() -> void:
	hide()
	get_tree().paused = previously_paused

func _exit_tree() -> void:
	if visible:
		get_tree().paused = previously_paused

func _input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		close()
		return
	var id := -1
	if event is InputEventScreenTouch:
		id = event.index
		if event.canceled:
			if close_pointer == id:
				close_pointer = -2
			return
	elif not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed and CLOSE_BUTTON.has_point(event.position) and close_pointer == -2:
		close_pointer = id
	elif not event.pressed and close_pointer == id:
		close_pointer = -2
		if CLOSE_BUTTON.has_point(event.position):
			close()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		close_pointer = -2

func _draw() -> void:
	var camp = get_parent()
	var art = camp.art
	draw_rect(Rect2(0,0,600,890), Color("#142c24d9"))
	art.box(self, Rect2(24,48,552,794), art.INK, 20)
	art.label(self, Vector2(48,99), "怪物图鉴", 32, art.CREAM)
	art.box(self, CLOSE_BUTTON, Color("#486653"), 10)
	art.centered(self, CLOSE_BUTTON.position.x, 95, CLOSE_BUTTON.size.x, "返回", 19, art.CREAM)
	art.label(self, Vector2(49,135), "普通怪物的生命和移速倍率以本波基础值为准。", 16, art.MINT)
	var y := 153
	for kind in Enemy.profiles:
		var stage := 1
		if kind == Enemy.Kind.BEETLE:
			stage = camp.path.BEETLE_STAGE
		elif kind == Enemy.Kind.SLIME:
			stage = camp.path.SLIME_STAGE
		draw_entry(art, y, Enemy.profiles[kind], "第 %d 关起" % stage, false)
		y += 113
	draw_entry(art, y, Enemy.boss_profile, "每关末波 · BOSS", true)

func draw_entry(art, y: int, profile: Enemy.Profile, appearance: String, boss: bool) -> void:
	art.box(self, Rect2(40,y,520,105), Color("#f3e3b8") if boss else art.CREAM, 12)
	var center := Vector2(84, y + 52)
	draw_circle(center, 32, Color("#d8d9ae"), true, -1, true)
	art.sprite(self, profile.portrait, center, 62)
	if boss:
		Enemy.draw_crown(self, center + Vector2(1,-18))
	art.label(self, Vector2(130,y+32), profile.display_name, 23, art.INK)
	art.label(self, Vector2(360,y+30), appearance, 15, Color("#596749"), 184, HORIZONTAL_ALIGNMENT_RIGHT)
	var movement := "生命 ×%s   移速 ×%s" % [str(profile.hp_multiplier), str(profile.speed_multiplier)]
	if boss:
		movement = "基础生命 %d   移速 %s px/s" % [profile.boss_base_hp, str(profile.boss_speed)]
	art.label(self, Vector2(130,y+61), "%s   ·   %s" % [profile.defenses_text(), movement], 16, art.INK)
	var trait_text := profile.guide_note
	if profile.dash_period > 0:
		trait_text += " · 每 %s 秒以 %s 倍速度冲刺 %s 秒" % [str(profile.dash_period),
				str(profile.dash_speed_multiplier), str(profile.dash_duration)]
	elif profile.heal_period > 0:
		trait_text += " · 每 %s 秒回复 %d%% 最大生命" % [str(profile.heal_period), profile.heal_percent]
	art.label(self, Vector2(130,y+87), trait_text, 16, Color("#4b604d"))
