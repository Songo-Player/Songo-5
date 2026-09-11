extends MarginContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func setup_display_for(music_record: TagLibMusicRecord):
	#current_song_duration = music_record.raw_length
	#%EndTimeLabel.text = music_record.get_length_string()
	var song_title = "%s ~ %s" % [music_record.title, music_record.artist]
	%CurrentSongTitle.set_carousel_text(song_title)
	


func _on_return_button_pressed() -> void:
	Input.action_press("select")

func _on_stop_button_pressed() -> void:
	Input.action_press("start")
