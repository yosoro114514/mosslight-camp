extends Node2D

const ENTER_BUTTON := Rect2(156, 637, 288, 70)
const RESTART_BUTTON := Rect2(310, 726, 195, 52)
const TUTORIAL_BUTTON := Rect2(200, 726, 200, 52)
const SAVED_TUTORIAL_BUTTON := Rect2(95, 726, 195, 52)
const BESTIARY_BUTTON := Rect2(24, 24, 132, 46)
const SOUND_BUTTON := Rect2(516, 24, 60, 46)
const FIREFLIES := [Vector2(78, 348), Vector2(108, 487), Vector2(172, 375),
		Vector2(208, 562), Vector2(308, 345), Vector2(404, 530), Vector2(482, 398),
		Vector2(521, 468), Vector2(437, 609)]

@onready var camp = get_parent()
var elapsed := 0.0
var pointer_id := -2
var pressed_button := Rect2()
var pointer := Vector2(-1, -1)
var confirming_restart := false

func _ready() -> void:
	get_tree().paused = true

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func enter_camp() -> void:
	camp.sound.activate()
	camp.sound.play_cue(&"tap")
	hide()
	get_tree().paused = false
	queue_free()

func _input(event: InputEvent) -> void:
	if not visible or camp.bestiary.visible:
		return
	get_viewport().set_input_as_handled()
	if confirming_restart and event.is_action_pressed("ui_cancel"):
		cancel_press()
		confirming_restart = false
		return
	if not confirming_restart and event.is_action_pressed("ui_accept"):
		enter_camp()
		return
	if event is InputEventMouseMotion or (event is InputEventScreenDrag and event.index == pointer_id):
		pointer = event.position
		return
	var id := -1
	if event is InputEventScreenTouch:
		id = event.index
		if event.canceled:
			if id == pointer_id:
				cancel_press()
			return
	elif not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed and pointer_id == -2:
		pointer_id = id
		pointer = event.position
		var buttons := [ENTER_BUTTON, BESTIARY_BUTTON, SOUND_BUTTON]
		if confirming_restart:
			buttons = [camp.NEW_RUN_CHOICE, camp.CANCEL_RESTART]
		else:
			buttons.append(tutorial_button())
			if camp.checkpoints.revision > 0:
				buttons.append(RESTART_BUTTON)
		for button: Rect2 in buttons:
			if button.has_point(pointer):
				pressed_button = button
				break
	elif not event.pressed and id == pointer_id:
		var button := pressed_button
		cancel_press()
		if button.has_point(event.position):
			if button == ENTER_BUTTON:
				enter_camp()
			elif button == BESTIARY_BUTTON:
				camp.bestiary.open()
			elif button == tutorial_button():
				camp.sound.activate()
				get_tree().paused = false
				get_tree().change_scene_to_file("res://scenes/tutorial.tscn")
			elif button == RESTART_BUTTON:
				camp.restart_error = ""
				confirming_restart = true
			elif button == camp.NEW_RUN_CHOICE:
				if camp.restart_run():
					enter_camp()
			elif button == camp.CANCEL_RESTART:
				confirming_restart = false
			elif button == SOUND_BUTTON:
				camp.sound.toggle_mute()
				camp.sound.activate()

func cancel_press() -> void:
	pointer_id = -2
	pressed_button = Rect2()
	pointer = Vector2(-1, -1)

func tutorial_button() -> Rect2:
	return SAVED_TUTORIAL_BUTTON if camp.checkpoints.revision > 0 else TUTORIAL_BUTTON

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_press()

func _exit_tree() -> void:
	if visible:
		get_tree().paused = false

func _draw() -> void:
	var art = camp.art
	draw_texture_rect(art.MEADOW, Rect2(0,0,600,890), false, Color("#73918f"))
	# Deepen the dusk at the edges of the clearing while keeping the camp in warm light.
	draw_polygon(PackedVector2Array([Vector2(0,0),Vector2(600,0),Vector2(600,445),Vector2(0,445)]),
			PackedColorArray([Color("#0d272cbe"),Color("#0d272cbe"),Color("#0d272c26"),Color("#0d272c26")]))
	draw_polygon(PackedVector2Array([Vector2(0,445),Vector2(600,445),Vector2(600,890),Vector2(0,890)]),
			PackedColorArray([Color("#0d272c26"),Color("#0d272c26"),Color("#0d272ce6"),Color("#0d272ce6")]))

	art.centered(self, 0, 168, 600, "无尽守夜", 22, art.GOLD)
	draw_line(Vector2(182,159), Vector2(238,159), art.GOLD, 1.5, true)
	draw_line(Vector2(362,159), Vector2(418,159), art.GOLD, 1.5, true)
	draw_string_outline(art.FONT, Vector2(0,257), "苔灯营地", HORIZONTAL_ALIGNMENT_CENTER, 600, 76, 8, art.INK)
	art.centered(self, 0, 254, 600, "苔灯营地", 76, art.CREAM)

	art.sprite(self, art.OWL, Vector2(369,359 + 4*sin(elapsed*1.8)), 101)
	art.sprite(self, art.BED, Vector2(300,446), 164)
	art.sprite(self, art.FOX, Vector2(191,455), 140)
	art.sprite(self, art.HARE, Vector2(408,466), 113)
	art.sprite(self, art.HEDGEHOG, Vector2(255,525), 91)
	for i in FIREFLIES.size():
		var phase := elapsed + i * 2.4
		var p: Vector2 = FIREFLIES[i] + Vector2(5*cos(phase*0.6), 8*sin(phase*0.8))
		var glow := 0.65 + 0.35*sin(phase*1.2)
		draw_circle(p, 7, Color(art.GOLD, 0.13*glow), true, -1, true)
		draw_circle(p, 2.2, Color(art.CREAM, glow), true, -1, true)

	var has_save: bool = camp.checkpoints.revision > 0
	draw_button(ENTER_BUTTON, "继续守夜" if has_save else "进入营地", art.GOLD, art.INK, 28)
	if has_save:
		var progress := "第 %d 关   ·   床铺 %d/%d   ·   %d 枚种子" % [camp.stage, camp.hp, camp.MAX_HP, camp.seeds]
		draw_string_outline(art.FONT,Vector2(0,613),progress,HORIZONTAL_ALIGNMENT_CENTER,600,18,4,art.INK)
		art.centered(self, 0, 613, 600, progress, 18, art.CREAM)
		draw_button(RESTART_BUTTON, "重新开始", Color("#38584a"), art.CREAM, 21)
	else:
		art.centered(self, 0, 612, 600, "初次守夜，可以先练习一波。", 19, art.CREAM)
	draw_button(tutorial_button(), "新手教程", Color("#38584a"), art.CREAM, 21)
	draw_button(BESTIARY_BUTTON, "怪物图鉴", art.INK, art.CREAM, 18)
	art.draw_sound_button(self, SOUND_BUTTON, camp.sound.muted)
	if confirming_restart:
		art.restart_menu(self, camp)

func draw_button(rect: Rect2, caption: String, fill: Color, ink: Color, font_size: int) -> void:
	var art = camp.art
	var face := rect
	if rect.has_point(pointer):
		fill = fill.lightened(0.15)
		if pressed_button == rect:
			face.position.y += 3
	var radius := 18 if rect == ENTER_BUTTON else 11
	art.box(self, Rect2(rect.position + Vector2(0,4), rect.size), art.INK, radius)
	art.box(self, face, fill, radius)
	art.centered(self, face.position.x, face.get_center().y + font_size * 0.35, face.size.x, caption, font_size, ink)
