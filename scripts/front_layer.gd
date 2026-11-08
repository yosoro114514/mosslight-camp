extends Node2D

func _draw() -> void:
	get_parent().paint_foreground(self)
