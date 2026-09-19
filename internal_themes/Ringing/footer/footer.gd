extends MarginContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Controller.page_changed.connect(_on_page_change)
	SongoPlayerV2.started_new_song.connect(_on_started_new_song)
	SongoPlayerV2.updated_repeat.connect(_on_updated_repeat)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _update_playlist_info():
	var music_record = SongoPlayerV2.current_song
	var song_title = "%s ~ %s" % [music_record.title, music_record.artist]
	%CurrentSongTitle.set_carousel_text(song_title)
	_set_next_song()

func _on_updated_repeat():
	await get_tree().process_frame
	_set_next_song()

func _set_next_song():
	var next_song = SongoPlayerV2.get_next_mp3_record()
	%NextSongTitle.set_carousel_text(next_song.title)

func _on_started_new_song(music_record):
	await get_tree().process_frame
	_update_playlist_info()

func _on_page_change():
	%MainSongViewFooter.visible = Controller.active_container is ThemeMainSongView
