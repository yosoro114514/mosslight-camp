extends "res://scripts/camp_book.gd"

const Art = preload("res://scripts/board_art.gd")
const OPEN_BUTTON := Rect2(389, 753, 80, 36)
const TABS := ["布阵", "伙伴", "成长", "守夜"]
const ENTRIES := [
	[
		[Art.FOX, "先看射程", "按住棋盘上的伙伴查看攻击范围。\n尽量让范围盖住一段路，拐角能兼顾两侧。"],
		[Art.HARE, "种下伙伴", "选顶部伙伴，再点空格。1 级花 3 枚种子，\n每次种植后要等 2.5 秒。击败一只怪得 2 枚。"],
		[Art.BLOOM, "换位与合成", "拖到空格可以换位。拖到同种、同等级的\n伙伴上，落点的伙伴升一级，最高 5 级。"],
		[Art.BED, "撤回与部署等级", "布阵时拖回顶部伙伴栏可以收回部分种子。\n用底部的 − 和 + 选等级，价格随等级上升。"],
	],
	[
		[Art.FOX, "叶狐  ·  物理", "三把旋刀扫过身边的道路。把叶狐种在\n拐角，怪物转弯时还能再挨一刀。"],
		[Art.HARE, "霜兔  ·  法术", "霜环同时攻击圈内的怪物，并减速 40%。\n让霜环和旋刀的范围重叠，能多打几次。"],
		[Art.OWL, "雷羽鸮  ·  法术", "瞄准射程内最接近床铺的怪物。闪电会\n跳向附近的敌人，普通形态最多打三只。"],
		[Art.HEDGEHOG, "松针猬  ·  物理", "射程最远，优先瞄准当前生命最高的怪物。\n重针单击伤害高，适合对付岩壳龟。"],
	],
	[
		[Art.HEDGEHOG, "全队训练", "每花 18 枚种子，全队基础攻击伤害加 1。\n训练也对后来种下的伙伴生效，跨关保留。"],
		[Art.FOX, "自动布阵", "托管优先合成，再用能买得起的最高等级\n种植当前所选伙伴。满级伙伴留给你操作。"],
		[Art.BLOOM, "满级超进化", "手动将两只同种、未超进化的 5 级伙伴\n拖到一起。选强攻或群攻会消耗拖入的一只。"],
		[Art.FROST_HARE, "形态与保底", "强攻每击伤害 ×4，群攻 ×2 并强化范围攻击。\n首次成功率 65%。失败后，带「保」的伙伴\n下次作为合成目标时必定成功。"],
	],
	[
		[Art.BED, "每关守三波", "伙伴自动攻击。每漏一只怪，床铺扣 1 生命。\n第三波末尾会出现金冠岩壳龟，守到最后\n床铺还有生命就能过关。"],
		[Art.OWL, "看波次，调阵容", "开波时按阵容锁定本波强度。战中可以\n补种、合成和训练，点「速度」切换倍速。"],
		[Art.HARE, "遇到格挡", "物理伤害要先扣防御，法术伤害受法抗影响。\n在「怪物图鉴」看数值，遇到岩壳龟可以\n换上霜兔或雷羽鸮。"],
		[Art.BLOOM, "继续与重试", "通关保留阵容和种子，再补 3 枚、修复 1 生命。\n战中退出或重试，回到本关开战前的布阵。\n「从第一关重新开始」会覆盖守夜进度。"],
	],
]

var page := 0

func tab_rect(index: int) -> Rect2:
	return Rect2(44 + index * 130, 139, 121, 49)

func button_at(pos: Vector2) -> Rect2:
	for index in TABS.size():
		if tab_rect(index).has_point(pos):
			return tab_rect(index)
	return super.button_at(pos)

func activate(button: Rect2) -> void:
	for index in TABS.size():
		if tab_rect(index) == button:
			page = index
			queue_redraw()
			return
	super.activate(button)

func _draw() -> void:
	var art = get_parent().art
	draw_rect(Rect2(0,0,600,890), Color("#142c24d9"))
	art.box(self, Rect2(24,48,552,794), art.INK, 20)
	art.label(self, Vector2(48,102), "守夜手册", 32, art.CREAM)
	art.box(self, CLOSE_BUTTON, Color("#486653"), 10)
	art.centered(self, CLOSE_BUTTON.position.x, 95, CLOSE_BUTTON.size.x, "返回", 19, art.CREAM)
	for index in TABS.size():
		var rect := tab_rect(index)
		art.box(self, rect, art.GOLD if page == index else Color("#395a48"), 10)
		art.centered(self, rect.position.x, 171, rect.size.x, TABS[index], 21, art.INK if page == index else art.CREAM)
	for row: int in ENTRIES[page].size():
		var entry: Array = ENTRIES[page][row]
		var top := 208 + row * 153
		art.box(self, Rect2(40,top,520,143), art.CREAM, 12)
		draw_circle(Vector2(85,top+65),32,Color("#e2e4bc"),true,-1,true)
		art.sprite(self,entry[0],Vector2(85,top+65),64)
		art.label(self, Vector2(133,top+39), entry[1], 23, art.INK)
		var lines: PackedStringArray = entry[2].split("\n")
		for i in lines.size():
			art.label(self, Vector2(133,top+72+i*25), lines[i], 17, Color("#415b48"))
