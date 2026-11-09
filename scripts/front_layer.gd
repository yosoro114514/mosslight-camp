extends Node2D

func _input(event: InputEvent) -> void:
	var camp = get_parent()
	if camp.restart_open:
		get_viewport().set_input_as_handled()
	elif get_tree().paused:
		return
	camp.handle_input(event)

func _draw() -> void:
	get_parent().paint_foreground(self)
