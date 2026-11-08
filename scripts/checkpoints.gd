extends RefCounted

const Evolution = preload("res://scripts/evolution.gd")

# Alternate slots so a partially written checkpoint leaves the last one readable.
static var prefix := "user://camp-run-"
var revision := 0

func latest(cells: int, kinds: int, max_level: int, max_hp: int) -> Dictionary:
	var newest := {}
	for slot in 2:
		var path := prefix + str(slot) + ".save"
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if not file:
			continue
		var data = file.get_var(false)
		if not data is Dictionary or data.get("version") != 1:
			continue
		var seq = data.get("revision")
		if not seq is int or seq <= revision:
			continue
		var valid := true
		for key in ["stage", "hp", "seeds", "training", "selected"]:
			if not data.get(key) is int or data[key] < 0:
				valid = false
		if not valid or data.stage < 1 or data.hp < 1 or data.hp > max_hp or data.selected >= kinds:
			continue
		var plant_level = data.get("plant_level", 1)
		if not plant_level is int or plant_level < 1 or plant_level > max_level:
			data["plant_level"] = 1
		if not data.get("levels") is PackedInt32Array or not data.get("allies") is PackedInt32Array:
			continue
		if data.levels.size() != cells or data.allies.size() != cells:
			continue
		if data.has("forms") and (not data.forms is PackedByteArray or data.forms.size() != cells):
			continue
		for i in cells:
			if data.levels[i] < 0 or data.levels[i] > max_level or data.allies[i] < 0 or data.allies[i] >= kinds:
				valid = false
			if data.has("forms") and (data.forms[i] > Evolution.Form.AREA or (data.forms[i] != Evolution.Form.NORMAL and data.levels[i] != max_level)):
				valid = false
		if valid:
			revision = seq
			newest = data
	return newest

func write(data: Dictionary) -> bool:
	var next := revision + 1
	var file := FileAccess.open(prefix + str(next % 2) + ".save", FileAccess.WRITE)
	if not file:
		return false
	data.version = 1
	data.revision = next
	file.store_var(data)
	file.flush()
	if file.get_error() != OK:
		return false
	revision = next
	return true
