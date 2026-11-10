extends Node2D

enum Step { WELCOME, PLANT_FOX, MERGE, SELECT_HARE, PLANT_HARE, START, EARN, SELECT_OWL, PLANT_OWL, WATCH, FINISHED, RETRY }
const FOX_CELL := 1
const MERGE_CELL := 0
const HARE_CELL := 4
const OWL_CELL := 3
const CARD_BUTTON := Rect2(195, 499, 210, 49)
const LESSONS := {
	Step.PLANT_FOX: ["种下第二只叶狐", "点金圈里的空格，花 3 枚种子种下叶狐。"],
	Step.MERGE: ["把两只叶狐合成", "按住右边的叶狐看射程，再拖到左边松手。"],
	Step.SELECT_HARE: ["给旋刀配一只霜兔", "点上方的霜兔。它能让怪物在刀下多停一会。"],
	Step.PLANT_HARE: ["让霜环盖住同一段路", "点金圈种下霜兔，让它和 2 级叶狐一起守入口。"],
	Step.START: ["放第一波怪物进来", "点「开始守夜」，看看怪物经过拐角时会怎样。"],
	Step.EARN: ["看种子从哪里来", "伙伴会自动攻击，每击败一只怪物就得 2 枚种子。"],
	Step.SELECT_OWL: ["用战利品补位", "种子够了！点上方的雷羽鸮，准备守住路的另一头。"],
	Step.PLANT_OWL: ["在床铺前补一道防线", "点右上方金圈。雷羽鸮会先打最靠近床铺的怪物。"],
	Step.WATCH: ["守完这一波", "留意漏过入口的怪物。点「速度」可以加快战斗。"],
}

@onready var camp = get_parent()
var step := Step.WELCOME
var wave_clear := false

func _ready() -> void:
	camp.get_node("PathSpawner").wave_cleared.connect(on_wave_cleared)

func _process(_delta: float) -> void:
	if step == Step.EARN and camp.seeds >= camp.plant_price(1):
		step = Step.SELECT_OWL
	if camp.phase == camp.Phase.LOST:
		step = Step.RETRY
	queue_redraw()

func on_wave_cleared() -> void:
	wave_clear = true
	camp.path.stop()
	if step == Step.WATCH:
		step = Step.FINISHED
	elif camp.seeds < camp.plant_price(1):
		step = Step.RETRY

func leave() -> void:
	get_tree().change_scene_to_file("res://scenes/start.tscn")

# Accept just the gesture being taught. The camp applies its usual costs,
# cooldown, merge and combat rules to every accepted board action.
func consume_release(pos: Vector2) -> bool:
	if camp.tapped(camp.RESTART_BUTTON, pos):
		leave()
		return true
	if camp.tapped(camp.SOUND_BUTTON, pos) or camp.tapped(camp.handbook.OPEN_BUTTON, pos) or camp.tapped(camp.bestiary.OPEN_BUTTON, pos):
		return false
	var cell: int = camp.cell_at(pos)
	match step:
		Step.WELCOME, Step.FINISHED, Step.RETRY:
			if camp.tapped(CARD_BUTTON, pos):
				match step:
					Step.WELCOME: step = Step.PLANT_FOX
					Step.FINISHED: get_tree().change_scene_to_file("res://scenes/camp.tscn")
					Step.RETRY: get_tree().reload_current_scene()
		Step.PLANT_FOX:
			return not (camp.pressed_cell == FOX_CELL and cell == FOX_CELL)
		Step.MERGE:
			return not (camp.pressed_cell == FOX_CELL and camp.dragging and cell == MERGE_CELL)
		Step.SELECT_HARE:
			return not camp.tapped(camp.ALLY_BUTTONS[camp.Ally.HARE], pos)
		Step.PLANT_HARE:
			return not (camp.pressed_cell == HARE_CELL and cell == HARE_CELL)
		Step.SELECT_OWL:
			if camp.tapped(camp.ALLY_BUTTONS[camp.Ally.OWL], pos):
				return false
		Step.PLANT_OWL:
			if camp.pressed_cell == OWL_CELL and cell == OWL_CELL:
				return false
		Step.START:
			return not camp.tapped(camp.BUTTON, pos)
	if not wave_clear and step in [Step.EARN, Step.SELECT_OWL, Step.PLANT_OWL, Step.WATCH]:
		return not camp.tapped(camp.BUTTON, pos)
	return true

func after_action() -> void:
	match step:
		Step.PLANT_FOX:
			if camp.levels[FOX_CELL] == 1: step = Step.MERGE
		Step.MERGE:
			if camp.levels[MERGE_CELL] == 2: step = Step.SELECT_HARE
		Step.SELECT_HARE:
			if camp.selected_ally == camp.Ally.HARE: step = Step.PLANT_HARE
		Step.PLANT_HARE:
			if camp.levels[HARE_CELL] == 1: step = Step.START
		Step.START:
			if camp.phase == camp.Phase.BATTLE: step = Step.EARN
		Step.SELECT_OWL:
			if camp.selected_ally == camp.Ally.OWL: step = Step.PLANT_OWL
		Step.PLANT_OWL:
			if camp.levels[OWL_CELL] == 1: step = Step.FINISHED if wave_clear else Step.WATCH
	queue_redraw()

func ring(center: Vector2) -> void:
	var radius := 36.0 + 2.0 * sin(camp.elapsed * 4.0)
	draw_arc(center, radius, 0, TAU, 56, camp.art.INK, 6, true)
	draw_arc(center, radius, 0, TAU, 56, camp.art.GOLD, 3, true)

func outline(rect: Rect2) -> void:
	draw_rect(rect.grow(1), camp.art.INK, false, 6, true)
	draw_rect(rect.grow(1), camp.art.GOLD, false, 3, true)

func highlight_target() -> void:
	match step:
		Step.WELCOME:
			ring(camp.BED_POS)
			var route: Curve2D = camp.path.curve
			var p := route.sample_baked(fmod(camp.elapsed * 230, route.get_baked_length()))
			draw_circle(p, 7, camp.art.INK, true, -1, true)
			draw_circle(p, 4, camp.art.GOLD, true, -1, true)
		Step.PLANT_FOX: ring(camp.cell_pos(FOX_CELL))
		Step.MERGE:
			var source: Vector2 = camp.cell_pos(FOX_CELL)
			var dest: Vector2 = camp.cell_pos(MERGE_CELL)
			ring(source)
			ring(dest)
			var tip := source.lerp(dest, 0.4 + 0.24 * fposmod(camp.elapsed, 1.0))
			draw_polyline(PackedVector2Array([tip+Vector2(8,-7),tip,tip+Vector2(8,7)]),camp.art.INK,7,true)
			draw_polyline(PackedVector2Array([tip+Vector2(8,-7),tip,tip+Vector2(8,7)]),camp.art.GOLD,3,true)
		Step.SELECT_HARE: outline(camp.ALLY_BUTTONS[camp.Ally.HARE])
		Step.PLANT_HARE: ring(camp.cell_pos(HARE_CELL))
		Step.START, Step.WATCH: outline(camp.BUTTON)
		Step.EARN: outline(Rect2(394,36,91,65))
		Step.SELECT_OWL: outline(camp.ALLY_BUTTONS[camp.Ally.OWL])
		Step.PLANT_OWL: ring(camp.cell_pos(OWL_CELL))

func _draw() -> void:
	var art = camp.art
	highlight_target()
	if step in [Step.WELCOME, Step.FINISHED, Step.RETRY]:
		var title := "守住路尽头的床铺"
		var lines := ["怪物从路标出发，沿着灰色小路绕向床铺。", "每漏一只扣 1 点生命。这次先练一波，", "练习用的伙伴和种子单独计算。"]
		var action := "开始练习"
		if step == Step.FINISHED:
			title = "第一波练习完成"
			lines = ["击败 %d 只怪物，床铺剩余 %d / %d 生命。" % [camp.hit_count,camp.hp,camp.MAX_HP], "正式守夜每关三波，最后会出现金冠岩壳龟。", "进入营地后，可随时翻看下方的「守夜手册」。"]
			action = "进入正式营地"
		elif step == Step.RETRY:
			title = "再练一次"
			lines = ["这次练习结束。", "重新布阵，让霜兔和叶狐一起守住入口。"]
			action = "重新练习"
		art.box(self, Rect2(82,329,436,239), art.INK, 17)
		art.centered(self,82,360,436,"新手教程  ·  独立练习",16,art.GOLD)
		art.centered(self,82,402,436,title,29,art.CREAM)
		for i in lines.size():
			art.centered(self,83,431+i*25,434,lines[i],17,art.CREAM)
		art.box(self,CARD_BUTTON,art.GOLD,11)
		art.centered(self,CARD_BUTTON.position.x,531,CARD_BUTTON.size.x,action,22,art.INK)
		return
	var lesson: Array = LESSONS[step]
	var body: String = lesson[1]
	if step in [Step.PLANT_HARE, Step.PLANT_OWL] and camp.plant_remaining > 0:
		body = "种植冷却还剩 %.1f 秒，金圈里的空格马上可用。" % camp.plant_remaining
	var progress := "布阵练习" if step <= Step.START else "守夜练习"
	if wave_clear:
		progress = "第一波已守住"
	art.box(self,Rect2(89,430,422,108),art.INK,13)
	art.label(self,Vector2(108,456),"%s  ·  %d / %d" % [progress,step,Step.WATCH],15,art.GOLD)
	art.label(self,Vector2(108,487),lesson[0],23,art.CREAM)
	art.centered(self,91,518,418,body,16,art.CREAM)
