extends Node2D

const CLOSE_BUTTON := Rect2(454, 66, 98, 44)

var previous_pause := false
var pointer_id := -2
var pressed_button := Rect2()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()

func open() -> void:
	if visible:
		return
	previous_pause = get_tree().paused
	pointer_id = -2
	show()
	get_tree().paused = true

func close() -> void:
	hide()
	get_tree().paused = previous_pause

func _exit_tree() -> void:
	if visible:
		get_tree().paused = previous_pause

func button_at(pos: Vector2) -> Rect2:
	return CLOSE_BUTTON if CLOSE_BUTTON.has_point(pos) else Rect2()

func activate(button: Rect2) -> void:
	if button == CLOSE_BUTTON:
		close()

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
			if id == pointer_id:
				pointer_id = -2
			return
	elif not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed and pointer_id == -2:
		pointer_id = id
		pressed_button = button_at(event.position)
	elif not event.pressed and pointer_id == id:
		pointer_id = -2
		if pressed_button.has_area() and pressed_button.has_point(event.position):
			activate(pressed_button)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		pointer_id = -2
