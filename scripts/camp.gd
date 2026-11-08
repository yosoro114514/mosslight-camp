extends Node2D

const BoardArt = preload("res://scripts/board_art.gd")
const Enemy = preload("res://scripts/enemy_mover.gd")
const Evolution = preload("res://scripts/evolution.gd")
const COLS := 4
const ROWS := 5
const PLANT_PRICES := [3, 7, 15, 31, 63]
const PLANT_COOLDOWN := 2.5
const BLADE_COUNT := 3
const ORBIT_SPEED := 3.0
const BLADE_REACH := 145.0
const BLADE_HIT_HALF_WIDTH := 10.0
const FROST_INTERVAL := 1.6
const FROST_REACH := 145.0
enum Ally { FOX, HARE, OWL, HEDGEHOG }
const ALLY_NAMES := ["叶狐", "霜兔", "雷羽鸮", "松针猬"]
const ALLY_ROLES := ["物理·旋刀", "法术·减速", "法术·连锁", "物理·重针"]
const ATTACK_RANGES := [BLADE_REACH, FROST_REACH, 198.0, 245.0]
# Relative contributions of one untrained unit, including range and support.
const POWER_WEIGHTS := [1.0, 1.05, 1.35, 1.25]
const EXPECTED_WAVE_POWER := [2.0, 5.0, 10.0]
const MAX_WAVE_HP_PERCENT := 5000
const ALLY_BUTTONS := [Rect2(20,128,136,50),Rect2(161,128,136,50),Rect2(302,128,136,50),Rect2(443,128,137,50)]
const AUTO_BUTTON := Rect2(209,849,152,37)
const LEVEL_DOWN_BUTTON := Rect2(369,797,48,43)
const LEVEL_UP_BUTTON := Rect2(505,797,48,43)
const TRAIN_BUTTON := Rect2(369,849,207,37)
const AUTO_INTERVAL := 0.65
# Favor the four bends of the road, then the remaining perimeter tiles.
const AUTO_CELLS := [0, 19, 3, 16, 4, 15, 7, 12, 1, 18, 2, 17, 8, 11, 5, 14, 6, 13, 9, 10]
const RECALL_RECT := Rect2(20,128,560,50)
const TRAIN_COST := 18
const MAX_HP := 5
const MAX_LEVEL := 5
const BUTTON := Rect2(389, 722, 164, 55)
const RESULT_BUTTON := Rect2(202, 495, 196, 52)
const NEW_RUN_BUTTON := Rect2(202, 587, 196, 40)
const BED_POS := Vector2(323, 220)
enum Phase { PREP, BATTLE, WON, LOST }

var phase := Phase.PREP
var stage := 1
var training := 0
var checkpoints := preload("res://scripts/checkpoints.gd").new()
var checkpoint := {}
var hp := MAX_HP
var seeds := 6
var levels := PackedInt32Array()
var allies := PackedInt32Array()
var forms := PackedByteArray()
var evolution := Evolution.new()
var attack_cooldowns := PackedFloat32Array()
var selected_ally := Ally.FOX
var plant_level := 1
var auto_enabled := false
var auto_delay := AUTO_INTERVAL
var orbit_phase := 0.0
var plant_remaining := 0.0
var sparks: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var attack_poses := {}
var hit_count := 0
var merge_count := 0
var elapsed := 0.0
var bed_flash := 0.0
var notice := ""
var notice_time := 0.0
var intermission := false
var pointer_id := -2
var pressed_cell := -1
var pressed_at := Vector2.ZERO
var pointer := Vector2(-999,-999)
var dragging := false
var art := BoardArt.new()
@onready var path = $PathSpawner

func _ready() -> void:
	levels.resize(COLS * ROWS)
	allies.resize(levels.size())
	forms.resize(levels.size())
	add_child(evolution)
	evolution.chosen.connect(resolve_evolution)
	attack_cooldowns.resize(levels.size())
	levels[0] = 1
	path.curve = make_route()
	path.hp_forecast = projected_hp_percent
	path.wave_started.connect(func(_wave): intermission = false)
	path.wave_cleared.connect(func(): intermission = true)
	path.enemy_resolved.connect(_on_enemy_resolved)
	path.completed.connect(func(): finish(true))
	checkpoint = checkpoints.latest(levels.size(), ALLY_NAMES.size(), MAX_LEVEL, MAX_HP)
	if checkpoint.is_empty():
		checkpoint = board_snapshot()
	else:
		restore_checkpoint()
	queue_redraw()

func projected_hp_percent(wave: int) -> int:
	var power := 0.0
	for cell in levels.size():
		var level := levels[cell]
		if level > 0:
			var factor := attack_multiplier(cell)
			power += POWER_WEIGHTS[allies[cell]] * ((1 << level) - 1 + 0.65 * training) * factor
	var expected: float = EXPECTED_WAVE_POWER[wave - 1] + 7.0 * (stage - 1)
	# A partial response keeps upgrades valuable even above the expected strength.
	var adjustment := 60.0 * (power - expected) / (power + expected)
	adjustment += 18.0 * maxf(0.0, power / expected - 2.0)
	return roundi(clampf(100.0 + adjustment, 80.0, MAX_WAVE_HP_PERCENT))

func board_snapshot() -> Dictionary:
	return {"stage":stage, "hp":hp, "seeds":seeds, "training":training, "selected":selected_ally,
			"levels":levels.duplicate(), "allies":allies.duplicate(), "forms":forms.duplicate(), "auto":auto_enabled,
			"plant_level":plant_level}

func save_board(next_stage := false) -> void:
	checkpoint = board_snapshot()
	if next_stage:
		checkpoint.stage += 1
		checkpoint.hp = mini(MAX_HP, hp + 1)
		checkpoint.seeds += 3
	if not checkpoints.write(checkpoint):
		message("进度保存失败，请检查磁盘空间")

func restore_checkpoint() -> void:
	stage = checkpoint.stage
	hp = checkpoint.hp
	seeds = checkpoint.seeds
	training = checkpoint.training
	selected_ally = checkpoint.selected
	plant_level = checkpoint.get("plant_level", 1)
	auto_enabled = checkpoint.get("auto", false) == true
	auto_delay = AUTO_INTERVAL
	levels = checkpoint.levels.duplicate()
	allies = checkpoint.allies.duplicate()
	forms.fill(Evolution.Form.NORMAL)
	if checkpoint.has("forms"):
		forms = checkpoint.forms.duplicate()
	path.reset_for_stage(stage)
	phase = Phase.PREP
	hit_count = 0
	merge_count = 0
	plant_remaining = 0
	notice_time = 0
	bed_flash = 0
	intermission = false
	orbit_phase = 0
	trails.clear()
	attack_poses.clear()
	sparks.clear()
	attack_cooldowns.fill(0)
	Engine.time_scale = 1.0
	cancel_pointer()

func save_preparation() -> void:
	if phase == Phase.PREP:
		save_board()

func make_route() -> Curve2D:
	var route := Curve2D.new()
	route.add_point(Vector2(248, 220))
	# Four quarter circles joined by straight stretches keep the track tangent at each corner.
	for corner in [[Vector2(111, 262), -90], [Vector2(111, 605), 180], [Vector2(489, 605), 90], [Vector2(489, 262), 0]]:
		for step in 13:
			var angle := deg_to_rad(float(corner[1]) - 90.0 * step / 12)
			route.add_point(corner[0] + Vector2.from_angle(angle) * 42)
	route.add_point(BED_POS)
	return route

func cell_pos(index: int) -> Vector2:
	return Vector2(165 + (index % COLS) * 90, 291 + floori(float(index) / COLS) * 71)

func cell_at(pos: Vector2) -> int:
	for i in levels.size():
		if cell_pos(i).distance_squared_to(pos) <= 32 * 32:
			return i
	return -1

func blade_half_width(level: int) -> float:
	return 6.0 + (level - 1) * 2.2

func blade_count(cell: int) -> int:
	return 6 if forms[cell] == Evolution.Form.AREA else BLADE_COUNT

func blade_angle(cell: int, blade: int, spin: float) -> float:
	return spin + cell * 0.71 + TAU * blade / blade_count(cell)

func attack_multiplier(cell: int) -> int:
	match forms[cell]:
		Evolution.Form.POWER: return 4
		Evolution.Form.AREA: return 2
	return 1

func attack_range(cell: int) -> float:
	if allies[cell] == Ally.HARE and forms[cell] == Evolution.Form.AREA:
		return FROST_REACH * 1.5
	return ATTACK_RANGES[allies[cell]]

func start_battle() -> void:
	if phase != Phase.PREP:
		return
	save_board()
	phase = Phase.BATTLE
	path.start()

func _process(delta: float) -> void:
	elapsed += delta
	notice_time = maxf(0, notice_time - delta)
	bed_flash = maxf(0, bed_flash - delta)
	for j in range(sparks.size() - 1, -1, -1):
		sparks[j].life -= delta
		if sparks[j].life <= 0:
			sparks.remove_at(j)
	for j in range(trails.size() - 1, -1, -1):
		trails[j].life -= delta
		if trails[j].life <= 0:
			trails.remove_at(j)
		else:
			var trail := trails[j]
			if is_instance_valid(trail.get("target")):
				trail.to = trail.target.position
			if is_instance_valid(trail.get("previous")):
				trail.from = trail.previous.position
	$Foreground.queue_redraw()

func _physics_process(delta: float) -> void:
	if phase > Phase.BATTLE:
		return
	plant_remaining = maxf(0.0, plant_remaining - delta)
	if auto_enabled and pointer_id == -2:
		auto_delay -= delta
		if auto_delay <= 0:
			auto_delay = AUTO_INTERVAL
			auto_deploy()
	var previous_phase := orbit_phase
	orbit_phase = fmod(orbit_phase + ORBIT_SPEED * delta, TAU)
	if phase == Phase.BATTLE:
		fire_support_units(delta)
	if phase == Phase.BATTLE:
		strike_with_blades(previous_phase)

func fire_support_units(delta: float) -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	for cell in levels.size():
		if levels[cell] == 0 or allies[cell] == Ally.FOX:
			continue
		attack_cooldowns[cell] = maxf(0, attack_cooldowns[cell] - delta)
		if attack_cooldowns[cell] > 0:
			continue
		var center := cell_pos(cell)
		if allies[cell] != Ally.HARE:
			fire_ranged(cell, center, enemies)
			if phase != Phase.BATTLE:
				return
			continue
		var reach := attack_range(cell)
		var duration := 0.9 + 0.2 * (levels[cell] - 1)
		if forms[cell] == Evolution.Form.AREA:
			duration += 2.0
		for enemy: Enemy in enemies:
			if enemy.is_destroyed or center.distance_squared_to(enemy.position) > reach * reach:
				continue
			if forms[cell] >= Evolution.Form.POWER:
				if attack_cooldowns[cell] == 0:
					begin_attack_pose(cell, enemy.position)
					trails.append({"pulse":true, "from":center, "reach":reach, "form":forms[cell], "life":0.46})
			attack_cooldowns[cell] = FROST_INTERVAL
			enemy.frost_remaining = maxf(enemy.frost_remaining, duration)
			enemy.get_damage(((1 << (levels[cell] - 1)) + training) * attack_multiplier(cell), Enemy.DamageType.MAGIC)
			if forms[cell] >= Evolution.Form.POWER:
				var delay := 0.0
				if forms[cell] == Evolution.Form.AREA:
					delay = 0.30 * clampf((center.distance_to(enemy.position) - 12) / (reach - 12), 0, 1)
				record_evolved_hit(cell, center, enemy, delay)
			if phase != Phase.BATTLE:
				return

func fire_ranged(cell: int, center: Vector2, enemies: Array) -> void:
	var owl := allies[cell] == Ally.OWL
	var reach: float = ATTACK_RANGES[allies[cell]]
	var target: Enemy
	for enemy: Enemy in enemies:
		if enemy.is_destroyed or center.distance_squared_to(enemy.position) > reach * reach:
			continue
		if target == null or (owl and enemy.progress > target.progress) or (not owl and enemy.hp > target.hp):
			target = enemy
	if target == null:
		return
	attack_cooldowns[cell] = 1.4 if owl else 1.75
	var damage := (2 if owl else 4) * (1 << (levels[cell] - 1)) + training
	damage *= attack_multiplier(cell)
	var area := forms[cell] == Evolution.Form.AREA
	var hits := 3 if owl else 1
	if area:
		hits = 6 if owl else 3
	var struck: Array[Enemy] = []
	var origin := center
	var evolved := forms[cell] >= Evolution.Form.POWER
	if evolved:
		begin_attack_pose(cell, target.position)
	for hop in hits:
		var end := target.position
		target.get_damage(damage, Enemy.DamageType.MAGIC if owl else Enemy.DamageType.PHYSICAL)
		if evolved:
			var delay := hop * (0.08 if area else 0.035)
			record_evolved_hit(cell, origin, target, delay, struck.back() if hop > 0 else null, hop)
		else:
			trails.append({"from":origin, "to":end, "owl":owl, "level":levels[cell], "form":forms[cell], "life":0.20})
		struck.append(target)
		if phase != Phase.BATTLE or hop + 1 == hits:
			break
		target = null
		var nearest := 95.0 * 95.0
		for enemy: Enemy in enemies:
			var distance := end.distance_squared_to(enemy.position)
			if not enemy.is_destroyed and not struck.has(enemy) and distance <= nearest:
				target = enemy
				nearest = distance
		if target == null:
			break
		origin = end
		damage = maxi(1, ceili(damage * (0.85 if area else 0.65)))

func strike_with_blades(previous_phase: float) -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	for cell in levels.size():
		if levels[cell] == 0 or allies[cell] != Ally.FOX:
			continue
		var center := cell_pos(cell)
		var contact_squared := pow(Enemy.BODY_RADIUS + BLADE_HIT_HALF_WIDTH, 2)
		for blade in blade_count(cell):
			var bit := 1 << blade
			var old_axis := Vector2.from_angle(blade_angle(cell, blade, previous_phase))
			var axis := Vector2.from_angle(blade_angle(cell, blade, orbit_phase))
			for enemy: Enemy in enemies:
				if enemy.is_destroyed:
					continue
				var contacts := int(enemy.blade_contacts.get(cell, 0))
				# Track the closest point on the whole shaft at each end of this physics tick.
				var before := enemy.previous_position - center
				var after := enemy.position - center
				var a := before - old_axis * clampf(before.dot(old_axis), 0, BLADE_REACH)
				var b := after - axis * clampf(after.dot(axis), 0, BLADE_REACH)
				var closest := b
				if not a.is_equal_approx(b):
					closest = Geometry2D.get_closest_point_to_segment(Vector2.ZERO, a, b)
				if (contacts & bit) == 0 and closest.length_squared() <= contact_squared:
					if forms[cell] >= Evolution.Form.POWER:
						begin_attack_pose(cell, enemy.position)
						record_evolved_hit(cell, center, enemy, 0)
					else:
						burst(enemy.position, art.LEVEL_COLORS[levels[cell] - 1])
					enemy.get_damage(((1 << levels[cell]) - 1 + training) * attack_multiplier(cell), Enemy.DamageType.PHYSICAL)
					if phase != Phase.BATTLE:
						return
				if b.length_squared() <= contact_squared:
					enemy.blade_contacts[cell] = contacts | bit
				elif contacts & bit:
					enemy.blade_contacts[cell] = contacts & ~bit

func begin_attack_pose(cell: int, target: Vector2) -> void:
	# Several blades can contact a pack on the same tick. Let one stroke read.
	if attack_poses.has(cell) and elapsed - float(attack_poses[cell].start) < 0.14:
		return
	attack_poses[cell] = {"start":elapsed, "aim":cell_pos(cell).direction_to(target)}

func record_evolved_hit(cell: int, origin: Vector2, target: Enemy, delay: float, previous: Enemy = null, hop := 0) -> void:
	var hit := {"kind":allies[cell], "form":forms[cell], "from":origin, "to":target.position,
			"target":target, "previous":previous, "hop":hop, "life":delay + art.StrikeFX.HIT_TIME}
	if delay > 0 and target.is_destroyed:
		hit.echo = Enemy.TEXTURES[target.kind]
		hit.echo_size = 78.0 if target.is_boss else Enemy.SIZES[target.kind]
		hit.echo_lift = 5 if target.kind == Enemy.Kind.MOTH else 0
	trails.append(hit)

func _on_enemy_resolved(leaked: bool) -> void:
	if leaked:
		hp = maxi(0, hp - 1)
		bed_flash = 0.45
		burst(BED_POS, Color("#ff796c"))
		if hp == 0:
			finish(false)
	else:
		seeds += 2
		hit_count += 1

func finish(won: bool) -> void:
	phase = Phase.WON if won else Phase.LOST
	path.stop()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.set_physics_process(false)
	cancel_pointer()
	if won:
		save_board(true)

func burst(pos: Vector2, color: Color) -> void:
	sparks.append({"pos": pos, "color": color, "life": 0.42})

func message(value: String) -> void:
	notice = value
	notice_time = 1.75

func plant_price(level: int = plant_level) -> int:
	return PLANT_PRICES[level - 1]

func auto_plant_level() -> int:
	for level in range(MAX_LEVEL, 1, -1):
		if seeds >= plant_price(level):
			return level
	return 1

func place(index: int, level: int = plant_level) -> void:
	if phase > Phase.BATTLE or levels[index] != 0 or plant_remaining > 0.0:
		return
	var price := plant_price(level)
	if seeds < price:
		message("种下 %d 级%s还差 %d 枚种子" % [level, ALLY_NAMES[selected_ally], price - seeds])
		return
	seeds -= price
	levels[index] = level
	forms[index] = Evolution.Form.NORMAL
	allies[index] = selected_ally
	attack_cooldowns[index] = 0.0
	plant_remaining = PLANT_COOLDOWN
	burst(cell_pos(index), art.LEVEL_COLORS[level - 1])
	save_preparation()

func drop_pet(source: int, dest: int) -> void:
	if dest < 0 or source == dest or levels[source] == 0:
		return
	if levels[dest] == 0:
		levels[dest] = levels[source]
		allies[dest] = allies[source]
		forms[dest] = forms[source]
		attack_cooldowns[dest] = attack_cooldowns[source]
		attack_poses.erase(dest)
	elif can_evolve(source, dest):
		evolution.open(source, dest)
		return
	elif can_merge(source, dest):
		levels[dest] += 1
		merge_count += 1
		burst(cell_pos(dest), art.LEVEL_COLORS[levels[dest] - 1])
		message("合成成功  ·  %d 级%s" % [levels[dest], ALLY_NAMES[allies[dest]]])
	else:
		message("伙伴已满级" if allies[source] == allies[dest] and levels[source] == MAX_LEVEL and levels[dest] == MAX_LEVEL else "相同种类、相同等级的伙伴可以合成")
		return
	levels[source] = 0
	attack_poses.erase(source)
	forms[source] = Evolution.Form.NORMAL
	attack_cooldowns[source] = 0.0
	save_preparation()

func can_merge(source: int, dest: int) -> bool:
	return allies[source] == allies[dest] and levels[source] == levels[dest] and levels[dest] < MAX_LEVEL

func can_evolve(source: int, dest: int) -> bool:
	return source != dest and levels[source] == MAX_LEVEL and levels[dest] == MAX_LEVEL \
			and allies[source] == allies[dest] and forms[source] <= Evolution.Form.GUARANTEED \
			and forms[dest] <= Evolution.Form.GUARANTEED

func resolve_evolution(choice: int) -> void:
	var source := evolution.source
	var dest := evolution.target
	if source < 0 or dest < 0:
		return
	evolution.close()
	if choice not in [Evolution.Form.POWER, Evolution.Form.AREA] or not can_evolve(source, dest):
		return
	var success := forms[dest] == Evolution.Form.GUARANTEED or randi_range(1,100) <= Evolution.SUCCESS_PERCENT
	levels[source] = 0
	forms[source] = Evolution.Form.NORMAL
	attack_cooldowns[source] = 0
	if success:
		forms[dest] = choice
		merge_count += 1
		burst(cell_pos(dest), Evolution.COLORS[choice - Evolution.Form.POWER])
		message("超进化成功 · %s" % Evolution.NAMES[allies[dest]][choice - Evolution.Form.POWER])
	else:
		forms[dest] = Evolution.Form.GUARANTEED
		message("超进化失败 · 目标保留，下次以它为目标必成")
	save_preparation()

func auto_deploy() -> void:
	var first_of_pair := {}
	for cell: int in AUTO_CELLS:
		var level := levels[cell]
		if level == 0 or level >= MAX_LEVEL:
			continue
		var key := Vector2i(allies[cell], level)
		if first_of_pair.has(key):
			drop_pet(cell, first_of_pair[key])
			return
		first_of_pair[key] = cell
	var buy_level := auto_plant_level()
	if seeds >= plant_price(buy_level) and plant_remaining <= 0:
		for cell: int in AUTO_CELLS:
			if levels[cell] == 0:
				place(cell, buy_level)
				return

func save_deployment_choice() -> void:
	# During combat, retain the pre-battle board used by retry and resume.
	checkpoint["auto"] = auto_enabled
	checkpoint.selected = selected_ally
	checkpoint.plant_level = plant_level
	if not checkpoints.write(checkpoint):
		message("进度保存失败，请检查磁盘空间")

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.canceled and event.index == pointer_id:
			cancel_pointer()
		elif event.pressed:
			begin_pointer(event.index, event.position)
		else:
			end_pointer(event.index, event.position)
	elif event is InputEventScreenDrag and event.index == pointer_id:
		move_pointer(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			begin_pointer(-1, event.position)
		else:
			end_pointer(-1, event.position)
	elif event is InputEventMouseMotion and pointer_id <= -1:
		move_pointer(event.position)

func begin_pointer(id: int, pos: Vector2) -> void:
	if pointer_id != -2:
		return
	pointer_id = id
	pressed_at = pos
	pointer = pos
	pressed_cell = cell_at(pos)

func move_pointer(pos: Vector2) -> void:
	pointer = pos
	if pressed_cell >= 0 and levels[pressed_cell] > 0 and pos.distance_to(pressed_at) >= 8:
		dragging = true

func end_pointer(id: int, pos: Vector2) -> void:
	if id != pointer_id:
		return
	move_pointer(pos)
	var dest := cell_at(pos)
	if phase == Phase.WON or phase == Phase.LOST:
		if RESULT_BUTTON.has_point(pressed_at) and RESULT_BUTTON.has_point(pos):
			restore_checkpoint()
		elif phase == Phase.LOST and NEW_RUN_BUTTON.has_point(pressed_at) and NEW_RUN_BUTTON.has_point(pos):
			stage = 1
			training = 0
			auto_enabled = false
			hp = MAX_HP
			seeds = 6
			selected_ally = Ally.FOX
			plant_level = 1
			allies.fill(Ally.FOX)
			levels.fill(0)
			forms.fill(Evolution.Form.NORMAL)
			levels[0] = 1
			save_board()
			restore_checkpoint()
	elif pressed_cell >= 0 and dragging:
		if phase == Phase.PREP and RECALL_RECT.has_point(pos):
			seeds += 1 << (levels[pressed_cell] - 1)
			levels[pressed_cell] = 0
			forms[pressed_cell] = Evolution.Form.NORMAL
			attack_cooldowns[pressed_cell] = 0
			save_board()
		else:
			drop_pet(pressed_cell, dest)
	elif pressed_cell >= 0 and pressed_cell == dest:
		if levels[dest] == 0:
			place(dest)
		elif levels[dest] == MAX_LEVEL:
			match forms[dest]:
				Evolution.Form.NORMAL: message("拖入同种 5 级伙伴可选择超进化")
				Evolution.Form.GUARANTEED: message("拖入同种 5 级伙伴 · 本次超进化必成")
				_: message("超进化 · %s" % Evolution.NAMES[allies[dest]][forms[dest] - Evolution.Form.POWER])
		else:
			message("%d 级%s  ·  拖至同种同级伙伴合成" % [levels[dest], ALLY_NAMES[allies[dest]]])
	elif LEVEL_DOWN_BUTTON.has_point(pressed_at) and LEVEL_DOWN_BUTTON.has_point(pos):
		change_plant_level(-1)
	elif LEVEL_UP_BUTTON.has_point(pressed_at) and LEVEL_UP_BUTTON.has_point(pos):
		change_plant_level(1)
	elif AUTO_BUTTON.has_point(pressed_at) and AUTO_BUTTON.has_point(pos):
		auto_enabled = not auto_enabled
		auto_delay = AUTO_INTERVAL
		notice_time = 0.0
		save_deployment_choice()
	elif TRAIN_BUTTON.has_point(pressed_at) and TRAIN_BUTTON.has_point(pos):
		if seeds >= TRAIN_COST:
			seeds -= TRAIN_COST
			training += 1
			message("全队训练成功，每次攻击伤害增加 1")
			save_preparation()
		else:
			message("全队训练需要 %d 枚种子" % TRAIN_COST)
	elif BUTTON.has_point(pressed_at) and BUTTON.has_point(pos):
		if phase == Phase.PREP:
			start_battle()
		elif phase == Phase.BATTLE:
			Engine.time_scale = 2.0 if Engine.time_scale == 1.0 else 1.0
	else:
		for kind in ALLY_BUTTONS.size():
			if ALLY_BUTTONS[kind].has_point(pressed_at) and ALLY_BUTTONS[kind].has_point(pos):
				selected_ally = kind
				notice_time = 0.0
				save_deployment_choice()
	cancel_pointer()

func change_plant_level(step: int) -> void:
	var next := clampi(plant_level + step, 1, MAX_LEVEL)
	if next != plant_level:
		plant_level = next
		notice_time = 0.0
		save_deployment_choice()

func cancel_pointer() -> void:
	pointer_id = -2
	pressed_cell = -1
	dragging = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_pointer()

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _draw() -> void:
	if is_instance_valid(path):
		art.paint_board(self)

func paint_foreground(layer: Node2D) -> void:
	art.paint_units(layer, self)
	art.paint_hud(layer, self)

