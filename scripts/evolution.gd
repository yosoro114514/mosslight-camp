extends Node2D

signal chosen(form: int)

enum Form { NORMAL, GUARANTEED, POWER, AREA }
const SUCCESS_PERCENT := 65
const NAMES := [
	["赤焰刃狐", "六刃风狐"], ["绯晶霜兔", "极夜雪兔"],
	["天罚雷鸮", "风暴雷鸮"], ["陨星针猬", "飞棘针猬"]
]
const PORTRAITS := [
	[preload("res://art/fox_power.png"), preload("res://art/fox_area.png")],
	[preload("res://art/hare_power.png"), preload("res://art/hare_area.png")],
	[preload("res://art/owl_power.png"), preload("res://art/owl_area.png")],
	[preload("res://art/hedgehog_power.png"), preload("res://art/hedgehog_area.png")]
]
const AREA_EFFECTS := ["三把旋刀增至六把", "霜环半径增加 50%，减速延长 2 秒",
	"闪电最多命中六只，每跳保留 85% 攻击", "重针可弹向附近敌人，最多命中三只"]
const COLORS := [Color("#ffad68"), Color("#72e8dd")]
const BUTTONS := [Rect2(82,369,436,76), Rect2(82,457,436,76), Rect2(194,562,212,48)]
var source := -1
var target := -1
var touch_id := -2
var pressed_button := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()

func open(from: int, to: int) -> void:
	source = from
	target = to
	show()
	get_tree().paused = true
	queue_redraw()

func close() -> void:
	hide()
	source = -1
	target = -1
	touch_id = -2
	pressed_button = -1
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		chosen.emit(Form.NORMAL)
		return
	var id := -1
	if event is InputEventScreenTouch:
		id = event.index
		if event.canceled:
			if touch_id == id:
				touch_id = -2
				pressed_button = -1
			return
	elif not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var button := -1
	for i in BUTTONS.size():
		if BUTTONS[i].has_point(event.position):
			button = i
	if event.pressed and touch_id == -2:
		touch_id = id
		pressed_button = button
	elif not event.pressed and touch_id == id:
		touch_id = -2
		if button >= 0 and button == pressed_button:
			chosen.emit([Form.POWER, Form.AREA, Form.NORMAL][button])
		pressed_button = -1

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		touch_id = -2
		pressed_button = -1

func _draw() -> void:
	if target < 0:
		return
	var camp = get_parent()
	var art = camp.art
	var kind: int = camp.allies[target]
	var guaranteed: bool = camp.forms[target] == Form.GUARANTEED
	draw_rect(Rect2(0,0,600,890),Color("#10261fe0"))
	art.box(self,Rect2(56,242,488,390),art.INK,19)
	art.centered(self,56,285,488,"%s · 超进化" % camp.ALLY_NAMES[kind],29,art.CREAM)
	var chance := "本次保底 · 成功率 100%" if guaranteed else "成功率 %d%% · 失败后该目标下次必成" % SUCCESS_PERCENT
	art.centered(self,56,323,488,chance,18,art.GOLD)
	art.centered(self,56,350,488,"选择形态即消耗拖入的 5 级伙伴",16,art.CREAM)
	for i in 2:
		var rect: Rect2 = BUTTONS[i]
		art.box(self,rect,COLORS[i],12)
		art.sprite(self,PORTRAITS[kind][i],rect.position+Vector2(44,38),68)
		art.label(self,rect.position+Vector2(88,31),NAMES[kind][i],23,art.INK)
		var effect: String = "每击攻击 ×4" if i == 0 else "攻击 ×2 · " + AREA_EFFECTS[kind]
		art.label(self,rect.position+Vector2(88,59),effect,15,art.INK)
	art.box(self,BUTTONS[2],Color("#476358"),10)
	art.centered(self,194,593,212,"取消 · 保留两只",18,art.CREAM)
