extends AudioStreamPlayer

@onready var nav_sfx = load("res://sound_effects/Abstract1.mp3")
@onready var accept_sfx = load("res://sound_effects/Cursor 1 (Sine).mp3")
@onready var back_sfx = load("res://sound_effects/Cancel 2 (Square).mp3")

func play_nav_sfx():
	if playing && stream != nav_sfx: return
	stream = nav_sfx
	play()
	
func play_accept_sfx():
	stream = accept_sfx
	play()
	
func play_back_sfx():
	stream = back_sfx
	play()
