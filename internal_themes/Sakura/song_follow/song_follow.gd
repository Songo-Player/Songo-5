extends MarginContainer

var current_song_duration = 100

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	update_play_time()
	
func update_play_time():
	if SongoPlayerV2.is_playing():
		var pos_sec: float = SongoPlayerV2.get_playback_position()
		var minutes: int = int(pos_sec) / 60
		var seconds: int = int(pos_sec) % 60
		%CurrentTimeLabel.text = "%d:%02d" % [minutes, seconds]
		var progress_ratio = pos_sec / current_song_duration
		%ProgressLine.scale.x = progress_ratio
		
func setup_display_for(music_record: TagLibMusicRecord):
	current_song_duration = music_record.raw_length
	%EndTimeLabel.text = music_record.get_length_string()
	var song_title = "%s ~ %s" % [music_record.title, music_record.artist]
	%SongTitle.set_carousel_text(song_title)
	
	if Artwork.song_cover_texture(music_record):
		%CoverImage.show()
		%CoverImage.texture = Artwork.song_cover_texture(music_record)
	else:
		%CoverImage.hide()
		
