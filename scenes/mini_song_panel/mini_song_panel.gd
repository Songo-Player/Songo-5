extends MarginContainer

var songo_data = SongoDataResource.get_instance()
var current_song_duration = 100
var loaded_song = null
@onready var songo_settings = SongoSettings.get_instance()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func setup():
	SongoPlayerV2.started_new_song.connect(_on_song_started)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if visible:
		update_play_time()
		handle_input(delta)
	
func handle_input(delta: float):
	if Input.is_action_just_pressed("L2") && SongoPlayerV2.is_playing():
		var target_playback = SongoPlayerV2.get_playback_position() - float(songo_settings.seek_backward_time)
		SongoPlayerV2.ffmpeg_audio_playback.seek(max(target_playback, 0.0))
		
	if Input.is_action_just_pressed("R2") && SongoPlayerV2.is_playing():
		var target_playback = SongoPlayerV2.get_playback_position() + float(songo_settings.seek_forward_time)
		var song_length = SongoPlayerV2.current_song.raw_length
		if song_length > 0.0: target_playback = min(target_playback, song_length)
		SongoPlayerV2.ffmpeg_audio_playback.seek(target_playback)

func update_play_time():
	if SongoPlayerV2.is_playing():
		var pos_sec: float = SongoPlayerV2.get_playback_position()
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
	
	#var image_extractor = Mp3ImageExtractor.new()
	#var image = image_extractor.get_cover_image(music_record.full_path)
	#if image == null: image = songo_data.get_album_cover(music_record.album)
	#if image == null:
	#	%CoverImage.hide()
	#else:
	#	%CoverImage.show()
	#	%CoverImage.texture = ImageTexture.create_from_image(image)
	
	if loaded_song == music_record.full_path: return
	var image_texture = null
	if false && music_record.full_path.get_extension() == "mp3":
		image_texture = music_record.image_texture
		if image_texture == null:
			var image = songo_data.get_album_cover(music_record.album)
			if image != null:
				image_texture = ImageTexture.create_from_image(image)
	else:	
		var image = songo_data.get_album_cover(music_record.album)
		if image != null:
			image_texture = ImageTexture.create_from_image(image)
		if image_texture == null:
			image_texture = music_record.image_texture
			
	if image_texture:
		%CoverImage.show()
		%CoverImage.texture = image_texture
	else:
		%CoverImage.hide()
		
	loaded_song = music_record.full_path

func _on_stop_music_button_pressed() -> void:
	UiHelper.dismiss_mini_song_panel()

func _on_return_to_music_button_pressed() -> void:
	Controller.restore_state()
