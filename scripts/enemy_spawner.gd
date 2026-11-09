# Adapted from exeldee's EnemySpawner.gd, MIT (LICENSE-template.txt).
extends Path2D

signal wave_started(number: int)
signal wave_cleared
signal boss_spawned
signal completed
signal enemy_resolved(leaked: bool)

const Enemy = preload("res://scripts/enemy_mover.gd")
const MUSHROOM = Enemy.Kind.MUSHROOM
const MOTH = Enemy.Kind.MOTH
const TURTLE = Enemy.Kind.TURTLE
const BEETLE_STAGE := 2
const SLIME_STAGE := 3
const MAX_PACK_SCALE := 5.0
const MAX_SPAWN_RATE := 4.0
const WAVES = [
	{"roster": [MUSHROOM, MUSHROOM, MOTH, MUSHROOM, MOTH, MUSHROOM], "hp": 4, "speed": 94, "interval": 1.4},
	{"roster": [MUSHROOM, MOTH, TURTLE, MUSHROOM, MOTH, MUSHROOM, MOTH, TURTLE], "hp": 8, "speed": 102, "interval": 1.12},
	{"roster": [TURTLE, MUSHROOM, MOTH, MOTH, TURTLE, MUSHROOM, MOTH, MUSHROOM, MOTH, TURTLE], "hp": 14, "speed": 112, "interval": 0.95}
]

var current_wave := 0
var current_wave_spawn_count := 0
var enemies_spawned_this_wave := 0
var resolved_this_wave := 0
var active := false
var boss: Enemy
var stage := 1
var wave_hp_percent := 100
var hp_forecast: Callable
var wave_interval := 0.0
var roster: Array = []

func reset_for_stage(number: int) -> void:
	stop()
	for child in get_children():
		if child is Enemy.HitFX:
			child.hide()
			child.queue_free()
		if child is Enemy:
			child.set_physics_process(false)
			child.remove_from_group("enemy")
			child.queue_free()
	boss = null
	stage = number
	current_wave = 0
	wave_hp_percent = 100
	wave_interval = 0.0
	current_wave_spawn_count = 0
	enemies_spawned_this_wave = 0
	resolved_this_wave = 0

func strength(base_hp: int) -> int:
	return base_hp + ceili(base_hp * 0.40 * (stage - 1))

func adjusted_hp(stage_hp: int) -> int:
	return maxi(1, roundi(stage_hp * (wave_hp_percent / 100.0)))

func extra_stage_enemies() -> int:
	return mini(stage - 1, 8)

func late_wave_pressure() -> float:
	return clampf((stage - 3) / 7.0, 0.0, 1.0)

func pack_size(wave: int, percent: int) -> int:
	var base_count: int = WAVES[wave - 1].roster.size() + extra_stage_enemies()
	var scale := percent / 100.0
	var pack_scale := minf(MAX_PACK_SCALE, scale + 0.5 * maxf(0.0, scale - 1.0))
	return roundi(base_count * pack_scale)

func spawn_interval(wave: int, percent: int) -> float:
	var base_interval := maxf(0.58, WAVES[wave - 1].interval - 0.035 * (stage - 1))
	return base_interval / minf(MAX_SPAWN_RATE, percent / 100.0)

func wave_roster(wave: int) -> Array:
	var members: Array = WAVES[wave - 1].roster.duplicate()
	if stage >= BEETLE_STAGE:
		# Rotate the original pack before inserting the later-stage enemies.
		for i in (stage + wave) % members.size():
			members.push_back(members.pop_front())
		for i in extra_stage_enemies():
			var kind := Enemy.Kind.BEETLE
			if stage >= SLIME_STAGE and (i + wave) % 2 == 1:
				kind = Enemy.Kind.SLIME
			members.insert((stage + 3 * i + wave) % (members.size() + 1), kind)
	return members

func start() -> void:
	active = true
	_on_wave_delay_timer_timeout()

func wave_hint(wave: int) -> String:
	if stage >= SLIME_STAGE:
		var slime: Enemy.Profile = Enemy.profiles[Enemy.Kind.SLIME]
		var beetle: Enemy.Profile = Enemy.profiles[Enemy.Kind.BEETLE]
		return "%s%s（法抗 %d%%） · %s%s" % [slime.display_name, slime.guide_note,
				slime.magic_resist_percent, beetle.display_name, beetle.guide_note]
	if stage >= BEETLE_STAGE:
		var beetle: Enemy.Profile = Enemy.profiles[Enemy.Kind.BEETLE]
		return "%s · %s · 防御 %d" % [beetle.display_name, beetle.guide_note, beetle.defense]
	var moth: Enemy.Profile = Enemy.profiles[MOTH]
	if wave == 0:
		return "首波 · %s与%s（法抗 %d%%）" % [Enemy.profiles[MUSHROOM].display_name, moth.display_name, moth.magic_resist_percent]
	if wave == 1:
		return "%s · 法抗 %d%%" % [moth.display_name, moth.magic_resist_percent]
	var focus: Enemy.Profile = Enemy.profiles[TURTLE] if wave == 2 else Enemy.boss_profile
	return "%s · %s" % [focus.display_name, focus.defenses_text()]

func stop() -> void:
	active = false
	$SpawnDelay.stop()
	$WaveDelayTimer.stop()

func _on_wave_delay_timer_timeout() -> void:
	if not active:
		return
	current_wave += 1
	enemies_spawned_this_wave = 0
	resolved_this_wave = 0
	roster = wave_roster(current_wave)
	wave_hp_percent = hp_forecast.call(current_wave) if hp_forecast.is_valid() else 100
	current_wave_spawn_count = pack_size(current_wave, wave_hp_percent)
	wave_interval = spawn_interval(current_wave, wave_hp_percent)
	wave_started.emit(current_wave)
	_on_spawn_delay_timeout()

func _on_spawn_delay_timeout() -> void:
	if not active or enemies_spawned_this_wave >= current_wave_spawn_count:
		return
	var stats: Dictionary = WAVES[current_wave - 1]
	var enemy := Enemy.new()
	var index := enemies_spawned_this_wave % roster.size()
	if current_wave_spawn_count < roster.size():
		# Sample across the full pack so that a smaller wave still has its closing enemy.
		index = roundi(enemies_spawned_this_wave * (roster.size() - 1.0) / (current_wave_spawn_count - 1))
	enemy.kind = roster[index]
	enemy.max_hp = adjusted_hp(ceili(strength(stats.hp) * enemy.profile.hp_multiplier))
	enemy.speed = stats.speed * (1.0 + minf(0.4, (stage - 1) * 0.035)) * enemy.profile.speed_multiplier
	enemy.hp = enemy.max_hp
	enemy.entry_guard = 0.85 * late_wave_pressure()
	enemy.loop = false
	enemy.rotates = false
	enemy.resolved.connect(enemy_destroyed)
	add_child(enemy)
	enemies_spawned_this_wave += 1
	if enemies_spawned_this_wave < current_wave_spawn_count:
		$SpawnDelay.start(wave_interval)

func spawn_final_boss() -> void:
	boss = Enemy.new()
	boss.kind = TURTLE
	boss.is_boss = true
	boss.max_hp = adjusted_hp(strength(boss.profile.boss_base_hp))
	boss.hp = boss.max_hp
	boss.entry_guard = 0.85 * late_wave_pressure()
	boss.speed = boss.profile.boss_speed
	boss.loop = false
	boss.rotates = false
	boss.resolved.connect(enemy_destroyed)
	current_wave_spawn_count += 1
	enemies_spawned_this_wave += 1
	add_child(boss)
	boss_spawned.emit()

func enemy_destroyed(leaked: bool) -> void:
	if not active:
		return
	resolved_this_wave += 1
	enemy_resolved.emit(leaked)
	if not active or resolved_this_wave < current_wave_spawn_count:
		return
	if current_wave == WAVES.size():
		if not is_instance_valid(boss):
			spawn_final_boss()
		else:
			stop()
			completed.emit()
	else:
		wave_cleared.emit()
		$WaveDelayTimer.start()
