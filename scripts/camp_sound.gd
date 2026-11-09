extends Node

const SETTINGS_PATH := "user://camp-audio.cfg"
const MUSIC := preload("res://audio/campfire.ogg")
# One voice per cue keeps packs and chain attacks from stacking identical sounds.
const CUES := {
	&"tap": [preload("res://audio/tap.wav"), -12.0],
	&"plant": [preload("res://audio/plant.wav"), -8.0],
	&"merge": [preload("res://audio/merge.wav"), -8.0],
	&"wave": [preload("res://audio/wave.wav"), -8.0],
	&"boss": [preload("res://audio/boss.wav"), -6.0],
	&"blade": [preload("res://audio/blade.wav"), -12.0],
	&"frost": [preload("res://audio/frost.wav"), -16.0],
	&"bolt": [preload("res://audio/bolt.wav"), -13.0],
	&"needle": [preload("res://audio/needle.wav"), -15.0],
	&"bed_hit": [preload("res://audio/bed_hit.wav"), -7.0],
	&"won": [preload("res://audio/won.wav"), -7.0],
	&"lost": [preload("res://audio/lost.wav"), -7.0],
}

var muted := false
var activated := false
var music := AudioStreamPlayer.new()
var voices: Dictionary[StringName, AudioStreamPlayer] = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		muted = settings.get_value("audio", "muted", false) == true
	music.stream = MUSIC
	music.volume_db = -15.0
	add_child(music)
	for cue: StringName in CUES:
		var voice := AudioStreamPlayer.new()
		voice.stream = CUES[cue][0]
		voice.volume_db = CUES[cue][1]
		add_child(voice)
		voices[cue] = voice
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		activate()

func activate() -> void:
	if activated:
		return
	activated = true
	if not muted:
		music.play()

func play_cue(cue: StringName) -> void:
	if activated and not muted:
		var voice := voices[cue]
		if not voice.playing:
			voice.play()

func toggle_mute() -> void:
	muted = not muted
	if muted:
		music.stop()
		for voice: AudioStreamPlayer in voices.values():
			voice.stop()
	elif activated:
		music.play()
		play_cue(&"tap")
	var settings := ConfigFile.new()
	settings.set_value("audio", "muted", muted)
	if settings.save(SETTINGS_PATH) != OK:
		push_warning("无法保存声音设置")
