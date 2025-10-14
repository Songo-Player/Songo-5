extends VBoxContainer

class_name SongPanelContainer

signal closing_container

var songo_player: SongoPlayer
var current_song_duration

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	
func setup(songo_player_arg):
	songo_player = songo_player_arg
	songo_player.started_new_song.connect(_on_started_new_song)
	
func handle_input(delta: float):
	if Input.is_action_just_pressed("ui_right"):
		_on_play_button_pressed()
		songo_player.play_next()
	
	if Input.is_action_just_pressed("ui_left"):
		var playback_position: float = songo_player.get_playback_position()
		display_play_button()
		if playback_position >= 3.0:
			songo_player.play_from_start()
		else:
			songo_player.play_previous()
	
	if Input.is_action_just_pressed("back"):
		songo_player.stop()
		closing_container.emit()
		
func render_ui():
	update_play_time()
	
func play():
	songo_player.play_from_start()
	%PauseButton.grab_focus()

func shuffle_play():
	songo_player.play_index = 0
	songo_player.mp3_files.shuffle()
	songo_player.play_from_start()
	%PauseButton.grab_focus()
		
func setup_display_for(mp3_record: Mp3Record):
	%EndTimeLabel.text = "00:00" # gets updated later
	%TitleLabel.set_carousel_text(mp3_record.title)
	%ArtistLabel.set_carousel_text(mp3_record.artist)
	%AlbumLabel.set_carousel_text(mp3_record.album)
	
	var image_extractor = Mp3ImageExtractor.new()
	var image = image_extractor.get_cover_image(mp3_record.full_path)
	if image == null:
		%MusicImage.hide()
	else:
		%MusicImage.show()
		%MusicImage.texture = ImageTexture.create_from_image(image)
	
func coalesce(value, default):
	return value if value != null and value != "" else default
	
func set_end_time(audio_stream: AudioStreamMP3):
	var length_sec: float = audio_stream.get_length()
	
	if length_sec < 0: 
		%EndTimeLabel.text = "00:00"
		return
		
	current_song_duration = length_sec
	var minutes: int = int(length_sec) / 60
	var seconds: int = int(length_sec) % 60
	%EndTimeLabel.text = "%d:%02d" % [minutes, seconds]
	
func update_play_time():
	if songo_player.playing:
		var pos_sec: float = songo_player.get_playback_position()
		var minutes: int = int(pos_sec) / 60
		var seconds: int = int(pos_sec) % 60
		%CurrentTimeLabel.text = "%d:%02d" % [minutes, seconds]
		var progress_ratio = pos_sec / current_song_duration
		%ProgressLine.scale.x = progress_ratio
		
func setup_playlist_info():
	var next_song = songo_player.get_next_mp3_record()
	%NextSongTitle.text = next_song.title
	%PlaylistProgress.text = "%d / %d" % [songo_player.play_index+1, songo_player.mp3_files.size()]

func display_play_button():
	%PlayButton.hide()
	%PauseButton.show()
	%PauseButton.grab_focus()
	
func display_pause_button():
	%PauseButton.hide()
	%PlayButton.show()
	%PlayButton.grab_focus()
	
##############################
#           SIGNALS          #
##############################
	
func _on_started_new_song(mp3_record: Mp3Record):
	setup_display_for(mp3_record)
	set_end_time(songo_player.stream)
	setup_playlist_info()
	
func _on_play_button_pressed() -> void:
	songo_player.resume()
	display_play_button()

func _on_pause_button_pressed() -> void:
	songo_player.pause()
	display_pause_button()
	
