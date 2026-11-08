extends RefCounted

const Evolution = preload("res://scripts/evolution.gd")
const StrikeFX = preload("res://scripts/strike_fx.gd")

const MEADOW = preload("res://art/meadow.webp")
const FOX = preload("res://art/fox.png")
const BLOOM = preload("res://art/fox_bloom.png")
const HARE = preload("res://art/hare.png")
const FROST_HARE = preload("res://art/hare_bloom.png")
const OWL = preload("res://art/owl.png")
const HEDGEHOG = preload("res://art/hedgehog.png")
const ALLY_TEXTURES = [[FOX, BLOOM], [HARE, FROST_HARE], [OWL,OWL], [HEDGEHOG,HEDGEHOG]]
const BED = preload("res://art/bed.png")
const FONT = preload("res://art/camp-type.otf")
const INK := Color("#203d34")
const CREAM := Color("#fff4d7")
const MINT := Color("#b9dca4")
const GOLD := Color("#efd18a")
const LEVEL_COLORS := [Color("#65cba4"), Color("#45a9ef"), Color("#f5b43f"), Color("#bd82ed"), Color("#f37262")]
var styles := {}
var silhouettes := {}

func box(n: CanvasItem, rect: Rect2, color: Color, radius: int) -> void:
	var key := "%s%d" % [color.to_html(), radius]
	if not styles.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(radius)
		style.corner_detail = 12
		styles[key] = style
	n.draw_style_box(styles[key], rect)

func label(n: CanvasItem, pos: Vector2, value: String, size: int, color: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	n.draw_string(FONT, pos, value, align, width, size, color)

func centered(n: CanvasItem, x: float, y: float, width: float, value: String, size: int, color: Color) -> void:
	label(n, Vector2(x,y), value, size, color, width, HORIZONTAL_ALIGNMENT_CENTER)

func sprite(n: CanvasItem, tex: Texture2D, pos: Vector2, size: float, tint := Color.WHITE) -> void:
	n.draw_texture_rect(tex, Rect2(pos - Vector2.ONE * size / 2.0, Vector2.ONE * size), false, tint)

func paint_board(n) -> void:
	n.draw_texture_rect(MEADOW, Rect2(0,0,600,890), false)
	# Outer and inner verges around the grey loop.
	box(n, Rect2(37,193,526,489), Color("#364c3e70"), 73)
	box(n, Rect2(38,189,524,489), Color("#51624b"), 72)
	box(n, Rect2(41,192,518,483), Color("#f4e3ae"), 69)
	box(n, Rect2(46,197,508,473), Color("#777e77"), 64)
	box(n, Rect2(49,200,502,467), Color("#858b83"), 61)
	box(n, Rect2(94,245,412,377), Color("#f6e8b8"), 20)
	box(n, Rect2(99,250,402,367), Color("#797f48"), 16)
	box(n, Rect2(102,253,396,361), Color("#aab863"), 14)
	box(n, Rect2(106,257,388,353), Color("#bdc96f"), 11)
	var curve: Curve2D = n.path.curve
	var length := curve.get_baked_length()
	var dist := 0.0
	while dist + 14 < length:
		var a := curve.sample_baked(dist)
		var b := curve.sample_baked(dist + 13)
		n.draw_line(a, b, Color("#e8e8ce"), 3, true)
		dist += 36
	for i in n.levels.size():
		var pos: Vector2 = n.cell_pos(i)
		n.draw_circle(pos + Vector2(0,2), 28, Color("#97a85a"), true, -1, true)
		n.draw_circle(pos, 28, Color("#d1d984"), true, -1, true)
		n.draw_circle(pos, 25.5, Color("#a4b65d"), true, -1, true)
		n.draw_circle(pos + Vector2(0,1), 23.5, Color("#b3c36a"), true, -1, true)
		n.draw_line(pos-Vector2(6,0),pos+Vector2(6,0),Color("#94a951"),3,true)
		n.draw_line(pos-Vector2(0,6),pos+Vector2(0,6),Color("#94a951"),3,true)
	# The striped trail marker separates the spawn from the bed at the end.
	box(n, Rect2(258,193,20,55), Color("#594c37"), 5)
	box(n, Rect2(261,196,14,49), Color("#f3d7a3"), 3)
	for y in [201, 216, 231]:
		n.draw_colored_polygon(PackedVector2Array([Vector2(261,y-3),Vector2(275,y+3),Vector2(275,y+9),Vector2(261,y+3)]), Color("#b25144"))
	sprite(n, BED, n.BED_POS + Vector2(0,-3), 67)
	# Painted chevron on the approach to the camp.
	for x in [204,218]:
		n.draw_polyline(PackedVector2Array([Vector2(x+4,215),Vector2(x-2,220),Vector2(x+4,225)]),Color("#faf1cb"),2.6,true)

func draw_blades(n: Node2D, g, cell: int) -> void:
	var center: Vector2 = g.cell_pos(cell)
	var level: int = g.levels[cell]
	var length: float = g.BLADE_REACH
	var width: float = g.blade_half_width(level)
	var form: int = g.forms[cell]
	var steel := attack_color(level, form)
	var rim := steel.darkened(0.56)
	var grip_start := 44.0
	var guard := 58.0
	var shoulder := length * 0.70
	var tip := Vector2(length, 0)
	var outline := PackedVector2Array([Vector2(guard,-width*0.55), Vector2(shoulder,-width), tip,
			Vector2(shoulder+width,width*0.72), Vector2(guard,width*0.68)])
	var bevel := PackedVector2Array([Vector2(guard,0), Vector2(shoulder,-width*0.22), tip,
			Vector2(shoulder+width,width*0.72), Vector2(guard,width*0.68)])
	var stroke := outline.duplicate()
	stroke.append(stroke[0])
	for blade in g.blade_count(cell):
		var angle: float = g.blade_angle(cell, blade, g.orbit_phase)
		if form == Evolution.Form.POWER:
			n.draw_arc(center,length-3,angle-0.28,angle,12,Color(steel,0.68),7,true)
		elif form == Evolution.Form.AREA:
			n.draw_arc(center,length-2,angle-0.70,angle,18,Color(steel,0.5),2,true)
			n.draw_arc(center,length*0.70,angle-0.42,angle,12,Color(steel,0.35),2,true)
		n.draw_arc(center,length,angle-0.27,angle,10,Color(steel,0.42),2.5,true)
		n.draw_set_transform(center, angle)
		n.draw_line(Vector2(grip_start,0),Vector2(guard,0),Color("#755034"),5,true)
		n.draw_circle(Vector2(grip_start,0),3.2,Color("#cbab73"),true,-1,true)
		n.draw_colored_polygon(outline,steel.lightened(0.42))
		n.draw_colored_polygon(bevel,steel)
		n.draw_polyline(stroke,rim,1.7,true)
		n.draw_line(Vector2(guard,-width),Vector2(guard,width),Color("#b18347"),4,true)
		n.draw_set_transform(Vector2.ZERO)

func paint_units(n, g) -> void:
	if g.plant_remaining > 0 and g.phase <= g.Phase.BATTLE:
		var progress: float = 1.0 - g.plant_remaining / g.PLANT_COOLDOWN
		for i in g.levels.size():
			if g.levels[i] != 0:
				continue
			var slot: Vector2 = g.cell_pos(i)
			n.draw_circle(slot,25,Color("#455d456b"),true,-1,true)
			if progress > 0.001:
				n.draw_arc(slot,24,-PI/2,-PI/2+TAU*progress,40,Color("#f4e5a4"),3,true)
			if slot.distance_squared_to(g.pointer) <= 32 * 32 and not g.dragging:
				centered(n,slot.x-22,slot.y+5,44,"%.1f" % (ceilf(g.plant_remaining * 10) / 10),15,CREAM)
	var highlight: int = g.cell_at(g.pointer)
	if highlight >= 0 and g.phase <= g.Phase.BATTLE:
		var pos: Vector2 = g.cell_pos(highlight)
		var color := Color("#fff1ab")
		if g.dragging and highlight != g.pressed_cell and g.levels[highlight] > 0 and not g.can_merge(g.pressed_cell,highlight) and not g.can_evolve(g.pressed_cell,highlight):
			color = Color("#d9725b")
		n.draw_arc(pos,29,0,TAU,52,color,3,true)
	if g.pressed_cell >= 0 and g.levels[g.pressed_cell] > 0 and not g.dragging:
		var radius: float = g.attack_range(g.pressed_cell)
		n.draw_circle(g.cell_pos(g.pressed_cell),radius,Color(LEVEL_COLORS[g.levels[g.pressed_cell]-1],0.12),true,-1,true)
		n.draw_arc(g.cell_pos(g.pressed_cell),radius,0,TAU,96,Color("#fff3aed0"),2,true)
	for i in g.levels.size():
		if g.levels[i] == 0:
			continue
		if g.allies[i] == g.Ally.FOX:
			draw_blades(n, g, i)
		elif g.allies[i] == g.Ally.HARE and g.forms[i] < Evolution.Form.POWER and g.attack_cooldowns[i] > g.FROST_INTERVAL - 0.38:
			var t: float = clampf((g.FROST_INTERVAL - g.attack_cooldowns[i]) / 0.38, 0, 1)
			var radius: float = lerpf(17.0,g.attack_range(i),t)
			var frost := attack_color(g.levels[i], g.forms[i])
			var center: Vector2 = g.cell_pos(i)
			n.draw_arc(center,radius,0,TAU,72,Color(frost.darkened(0.48),1-t),5,true)
			n.draw_arc(center,radius,0,TAU,72,Color(frost,1-t),3,true)
			for shard in 8:
				var dir := Vector2.from_angle(shard * TAU / 8)
				n.draw_line(center+dir*(radius-5),center+dir*(radius+5),Color(frost.lightened(0.32),1-t),3,true)
	for i in g.levels.size():
		if g.levels[i] <= 0:
			continue
		if g.dragging and g.pressed_cell == i:
			continue
		draw_pet(n, g.cell_pos(i), g.allies[i], g.levels[i], sin(g.elapsed*2.7+i)*1.2, g.forms[i], g.elapsed, StrikeFX.pose(g,i))
	for trail in g.trails:
		if trail.has("pulse"):
			StrikeFX.frost_pulse(n, trail)
			continue
		if trail.has("kind"):
			StrikeFX.draw_hit(n, g, trail)
			continue
		var origin: Vector2 = trail.from
		var end: Vector2 = trail.to
		var alpha: float = trail.life / 0.2
		var form: int = trail.get("form", Evolution.Form.NORMAL)
		var hue := attack_color(trail.level, form)
		var edge := Color(hue.darkened(0.52),alpha)
		var body := Color(hue,alpha)
		if trail.owl:
			var bend := (end-origin).orthogonal().normalized()*8
			var points := PackedVector2Array([origin,origin.lerp(end,0.4)+bend,origin.lerp(end,0.6)-bend,end])
			n.draw_polyline(points,edge,7,true)
			n.draw_polyline(points,body,5,true)
			n.draw_polyline(points,Color(hue.lightened(0.55),alpha),1.5,true)
		else:
			n.draw_line(origin,end,edge,4,true)
			n.draw_line(origin,end,body,2.5,true)
			n.draw_circle(end,4.5,edge,true,-1,true)
			n.draw_circle(end,3.2,body,true,-1,true)
	for spark in g.sparks:
		var t: float = 1 - spark.life / 0.42
		var col: Color = spark.color
		col.a = 1 - t
		for j in 8:
			var d := Vector2.from_angle(j * TAU / 8 + 0.2)
			n.draw_line(spark.pos + d * (5 + 24*t), spark.pos + d*(10+26*t), col, 2.6, true)
	if g.bed_flash > 0:
		n.draw_arc(g.BED_POS,34,0,TAU,48,Color("#ed785a"),3,true)
		label(n, g.BED_POS + Vector2(32,-22), "−1", 22, Color("#b04335"))
	if g.dragging:
		draw_pet(n, g.pointer-Vector2(0,8),g.allies[g.pressed_cell],g.levels[g.pressed_cell],0,g.forms[g.pressed_cell],g.elapsed)

func silhouette(texture: Texture2D) -> Texture2D:
	if not silhouettes.has(texture):
		var mask := texture.get_image()
		if mask.is_compressed():
			mask.decompress()
		mask.resize(80,80,Image.INTERPOLATE_BILINEAR)
		for y in mask.get_height():
			for x in mask.get_width():
				mask.set_pixel(x,y,Color(1,1,1,mask.get_pixel(x,y).a))
		silhouettes[texture] = ImageTexture.create_from_image(mask)
	return silhouettes[texture]

func attack_color(level: int, form: int) -> Color:
	if form >= Evolution.Form.POWER:
		return Evolution.COLORS[form - Evolution.Form.POWER]
	return LEVEL_COLORS[level - 1]

func draw_pet(n, pos: Vector2, kind: int, level: int, bob: float, form := Evolution.Form.NORMAL, time := 0.0, pose := Transform2D.IDENTITY) -> void:
	var color := attack_color(level, form)
	var evolved := form >= Evolution.Form.POWER
	if evolved:
		var radius := 33.0 + 2.0*sin(time*3.2)
		n.draw_circle(pos,radius+3,Color(color,0.18),true,-1,true)
		for i in 4:
			var angle := time*1.8 + i*TAU/4
			var point := pos + Vector2.from_angle(angle)*radius
			n.draw_arc(pos,radius,angle-0.48,angle,12,Color(color,0.8),2,true)
			n.draw_circle(point,2.7,color,true,-1,true)
	n.draw_set_transform(pos + Vector2(0,13),0,Vector2(1,0.55))
	n.draw_circle(Vector2.ZERO,28,INK,true,-1,true)
	n.draw_circle(Vector2.ZERO,26.5,color,true,-1,true)
	n.draw_circle(Vector2.ZERO,21.5,color.darkened(0.47),true,-1,true)
	n.draw_set_transform(Vector2.ZERO)
	var size := 52.0 if level == 1 else 60.0
	if evolved:
		size = 68.0
	var portrait: Texture2D = ALLY_TEXTURES[kind][int(level > 1)]
	if evolved:
		portrait = Evolution.PORTRAITS[kind][form - Evolution.Form.POWER]
	var center := pos + Vector2(0,-6+bob)
	n.draw_set_transform_matrix(Transform2D(0,center) * pose)
	var mask := silhouette(portrait)
	for offset: Vector2 in [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN]:
		sprite(n,mask,offset * 2.6,size,color)
	sprite(n,portrait,Vector2.ZERO,size,Color.WHITE if evolved else Color.WHITE.lerp(color,0.15))
	n.draw_set_transform(Vector2.ZERO)
	var badge := pos+Vector2(20,15)
	n.draw_circle(badge,12.5,INK,true,-1,true)
	n.draw_circle(badge,10.5,color,true,-1,true)
	var badge_text := str(level)
	if evolved:
		badge_text = "超"
	elif form == Evolution.Form.GUARANTEED:
		badge_text = "保"
	centered(n,badge.x-11,badge.y+5.1,22,badge_text,15,Color("#14291f"))

func draw_seed(n, p: Vector2) -> void:
	n.draw_set_transform(p, -0.55, Vector2(0.77,1))
	n.draw_circle(Vector2.ZERO,10,Color("#e8af50"),true,-1,true)
	n.draw_arc(Vector2.ZERO,8,PI*0.92,PI*1.5,10,Color("#ffe5a7"),2,true)
	n.draw_set_transform(Vector2.ZERO)
	n.draw_colored_polygon(PackedVector2Array([p+Vector2(1,-7),p+Vector2(3,-14),p+Vector2(10,-15),p+Vector2(8,-10)]),MINT)

func heart(n, p: Vector2) -> void:
	var color := Color("#eb947e")
	n.draw_circle(p+Vector2(-4,-2),5.6,color,true,-1,true)
	n.draw_circle(p+Vector2(4,-2),5.6,color,true,-1,true)
	n.draw_colored_polygon(PackedVector2Array([p+Vector2(-9,-1),p+Vector2(9,-1),p+Vector2(0,9)]),color)

func paint_hud(n, g) -> void:
	box(n, Rect2(20,24,560,98), Color("#203a3055"), 18)
	box(n, Rect2(20,20,560,98), INK, 18)
	box(n, Rect2(25,25,550,88), Color("#2d4d40"), 14)
	label(n, Vector2(44,51), "第 %d 关   /   无尽守夜" % g.stage, 15, GOLD)
	label(n, Vector2(41,94), "苔灯营地", 37, CREAM)
	var preview: bool = g.phase == g.Phase.PREP or g.intermission
	var wave: int = g.path.current_wave
	var shown_wave: int = clampi(wave + int(preview), 1, g.path.WAVES.size())
	var percent: int = g.projected_hp_percent(shown_wave) if preview else g.path.wave_hp_percent
	if g.phase <= g.Phase.BATTLE:
		label(n,Vector2(201,58),"下波生命" if preview else "本波生命",14,MINT)
		label(n,Vector2(201,90),"×%.2f" % (percent / 100.0),22,GOLD)
	n.draw_line(Vector2(292,42),Vector2(292,94),Color("#6c8267"),1)
	heart(n, Vector2(322,59))
	label(n,Vector2(342,62),"床铺",15,MINT)
	label(n,Vector2(315,92),"%d / %d" % [g.hp,g.MAX_HP],24,CREAM)
	draw_seed(n, Vector2(451,59))
	label(n,Vector2(469,62),"种子",15,MINT)
	label(n,Vector2(445,92),str(g.seeds),24,CREAM)
	var buy_level: int = g.auto_plant_level() if g.auto_enabled else g.plant_level
	var price: int = g.plant_price(buy_level)
	if g.phase <= g.Phase.BATTLE:
		box(n,Rect2(23,849,178,37),INK,10)
		draw_seed(n,Vector2(44,870))
		var status_text := "可种植" if g.seeds >= price else "种子不足"
		if g.plant_remaining > 0.0:
			status_text = "冷却  %.1f 秒" % (ceilf(g.plant_remaining * 10) / 10)
		label(n,Vector2(62,874),status_text,16,CREAM)
		var fill: float = 1.0 - g.plant_remaining / g.PLANT_COOLDOWN
		box(n,Rect2(155,866,31,5),Color("#526c56"),2)
		if fill > 0.025:
			box(n,Rect2(155,866,31*fill,5),GOLD,2)
		box(n,g.AUTO_BUTTON,GOLD if g.auto_enabled else INK,10)
		var auto_ink := INK if g.auto_enabled else CREAM
		label(n,g.AUTO_BUTTON.position+Vector2(12,24),"自动布阵",17,auto_ink)
		var switch_pos: Vector2 = g.AUTO_BUTTON.position+Vector2(98,9)
		box(n,Rect2(switch_pos,Vector2(40,19)),INK if g.auto_enabled else Color("#597163"),10)
		n.draw_circle(switch_pos+Vector2(30 if g.auto_enabled else 10,9.5),7,GOLD if g.auto_enabled else CREAM,true,-1,true)
		box(n,g.TRAIN_BUTTON,INK,10)
		centered(n,g.TRAIN_BUTTON.position.x,874,g.TRAIN_BUTTON.size.x,"训练 +%d   ·   18 种子" % g.training,16,CREAM if g.seeds >= g.TRAIN_COST else MINT)
		for kind in g.ALLY_BUTTONS.size():
			var rect: Rect2 = g.ALLY_BUTTONS[kind]
			var selected: bool = g.selected_ally == kind
			box(n,rect,GOLD if selected else INK,10)
			box(n,rect.grow(-2),INK if selected else CREAM,8)
			sprite(n,ALLY_TEXTURES[kind][0],rect.position+Vector2(25,25),38)
			label(n,rect.position+Vector2(51,23),g.ALLY_NAMES[kind],18,CREAM if selected else INK)
			label(n,rect.position+Vector2(51,41),g.ALLY_ROLES[kind],13,GOLD if selected else Color("#48634e"))
		if g.dragging and g.phase == g.Phase.PREP:
			box(n,g.RECALL_RECT,INK,10)
			centered(n,20,160,560,"松手撤回伙伴   ·   回收 %d 枚种子" % (1 << (g.levels[g.pressed_cell]-1)),18,CREAM)
	box(n,Rect2(21,702,558,150),Color("#32433077"),17)
	box(n,Rect2(20,697,560,150),Color("#465538"),17)
	box(n,Rect2(23,700,554,144),CREAM,15)
	var status := "布阵时间"
	if g.phase == g.Phase.BATTLE:
		status = "准备下一波" if g.intermission else "第 %d 波来袭" % wave
	elif g.phase > g.Phase.BATTLE:
		status = "守夜结束"
	var roster := ["首波 · 蘑菇怪与疾翅蛾（法抗 25%）","疾翅蛾 · 法抗 25%","岩壳龟 · 防御 1 · 法抗 -20%","金冠岩壳龟 · 防御 2 · 法抗 -20%"]
	if g.stage >= 2:
		var threat := "本关 · 赤角甲虫冲刺 · 防御 1" if g.stage == 2 else "本关 · 苔灵回血（法抗 35%） · 甲虫冲刺"
		roster.fill(threat)
	var boss = g.path.boss
	if g.phase == g.Phase.BATTLE and is_instance_valid(boss) and not boss.is_destroyed:
		box(n,Rect2(44,720,54,25),Color("#873e35"),6)
		centered(n,44,739,54,"BOSS",14,CREAM)
		label(n,Vector2(106,740),"岩壳龟",21,INK)
		label(n,Vector2(45,787),"防御 2 · 法抗 -20%",14,INK)
		label(n,Vector2(218,740),"%d / %d" % [ceili(boss.hp),boss.max_hp],18,INK,144,HORIZONTAL_ALIGNMENT_RIGHT)
		box(n,Rect2(44,755,320,16),Color("#553d32"),8)
		var fraction := clampf(float(boss.hp) / boss.max_hp,0,1)
		box(n,Rect2(47,758,314*fraction,10),Color("#d76e4d"),4)
	else:
		label(n,Vector2(46,735),roster[shown_wave] if g.intermission else roster[wave],14,Color("#657457"))
		label(n,Vector2(44,770),status,25,INK)
		var count: int = g.path.pack_size(shown_wave,percent) if preview else g.path.current_wave_spawn_count
		var interval: float = g.path.spawn_interval(shown_wave,percent) if preview else g.path.wave_interval
		if g.phase <= g.Phase.BATTLE:
			label(n,Vector2(202,766),"%d 只 · %.2f 秒/只" % [count,interval],17,Color("#49613d"))
	box(n,g.BUTTON,Color("#264a3c"),11)
	var action := "开始守夜" if g.phase == g.Phase.PREP else ("速度  ×2" if Engine.time_scale > 1 else "速度  ×1")
	centered(n,g.BUTTON.position.x,758,g.BUTTON.size.x,action,21,CREAM)
	n.draw_line(Vector2(44,791),Vector2(554,791),Color("#d6d3af"),1.5)
	if g.phase <= g.Phase.BATTLE:
		var action_text := "自动种植 %d 级" % buy_level if g.auto_enabled else "点空格种植"
		label(n,Vector2(45,813),"%s%s" % [action_text,g.ALLY_NAMES[g.selected_ally]],16,INK)
		var cost_text := "每只 %d 枚种子" % price
		if g.seeds < price:
			cost_text += "  ·  还差 %d 枚" % (price - g.seeds)
		label(n,Vector2(45,834),cost_text,15,Color("#94432e") if g.seeds < price else Color("#49613d"))
		for button: Rect2 in [g.LEVEL_DOWN_BUTTON, g.LEVEL_UP_BUTTON]:
			var down: bool = button == g.LEVEL_DOWN_BUTTON
			var enabled: bool = g.plant_level > 1 if down else g.plant_level < g.MAX_LEVEL
			box(n,button,INK if enabled else Color("#d8dcc8"),9)
			centered(n,button.position.x,826,button.size.x,"-" if down else "+",24,CREAM if enabled else Color("#63745f"))
		centered(n,417,812,88,"手动等级" if g.auto_enabled else "部署等级",13,Color("#49613d"))
		centered(n,417,834,88,"%d 级" % g.plant_level,20,INK)
		if g.notice_time > 0:
			box(n,Rect2(23,651,554,39),INK,10)
			centered(n,23,677,554,g.notice,16,CREAM)
	if g.phase == g.Phase.WON or g.phase == g.Phase.LOST:
		result(n,g)

func result(n, g) -> void:
	var won: bool = g.phase == g.Phase.WON
	n.draw_rect(Rect2(0,0,600,890),Color("#132d27ac"))
	box(n,Rect2(79,292,442,293),INK,21)
	box(n,Rect2(84,297,432,283),CREAM,17)
	sprite(n,BLOOM if won else BED,Vector2(300,352),70)
	centered(n,85,424,430,("第 %d 关守住了" if won else "第 %d 关失守") % g.stage,31,INK)
	centered(n,85,464,430,"击败 %d 个敌人   ·   合成 %d 次" % [g.hit_count,g.merge_count],18,Color("#677354"))
	box(n,g.RESULT_BUTTON,INK,10)
	centered(n,202,529,196,("进入第 %d 关" % (g.stage + 1)) if won else "重试本关",21,CREAM)
	centered(n,90,567,420,"继承阵容与种子  ·  补给 3 种子、修复 1 生命" if won else "返回开战前的布阵和资源",16,Color("#52694e"))
	if not won:
		box(n,g.NEW_RUN_BUTTON,INK,9)
		centered(n,202,614,196,"从第一关重新开始",16,CREAM)

