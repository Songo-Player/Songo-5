extends MarginContainer

var songo_data = SongoDataResource.get_instance()
var current_song_duration = 100

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func setup():
	SongoPlayer.started_new_song.connect(_on_song_started)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	update_play_time()
	pass

func update_play_time():
	if SongoPlayer.is_playing():
		var pos_sec: float = SongoPlayer.get_playback_position()
		var minutes: int = int(pos_sec) / 60
		var seconds: int = int(pos_sec) % 60
		%CurrentTimeLabel.text = "%d:%02d" % [minutes, seconds]
		var progress_ratio = pos_sec / current_song_duration
		%ProgressLine.scale.x = progress_ratio
		
func _on_song_started(music_record: MusicRecord):
	current_song_duration = music_record.raw_length
	%EndTimeLabel.text = music_record.length
	var song_title = "%s ~ %s" % [music_record.title, music_record.artist]
	%SongTitle.set_carousel_text(song_title)
	
	var image_extractor = Mp3ImageExtractor.new()
	var image = image_extractor.get_cover_image(music_record.full_path)
	if image == null: image = songo_data.get_album_cover(music_record.album)
	if image == null:
		%CoverImage.hide()
	else:
		%CoverImage.show()
		%CoverImage.texture = ImageTexture.create_from_image(image)
