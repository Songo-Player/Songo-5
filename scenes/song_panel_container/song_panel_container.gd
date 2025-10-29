extends VBoxContainer

class_name SongPanelContainer

signal closing_container

var songo_player: SongoPlayer
var current_song_duration
var songo_data = SongoDataResource.get_instance()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	
func setup(songo_player_arg):
	songo_player = songo_player_arg
	songo_player.started_new_song.connect(_on_started_new_song)
	
func handle_input(delta: float):
	if Input.is_action_just_pressed("ui_right"):
		songo_player.play_next()
		display_play_button()
	
	if Input.is_action_just_pressed("ui_left"):
		var playback_position: float = songo_player.get_playback_position()
		display_play_button()
		if playback_position >= 3.0:
			songo_player.play_from_start()
		else:
			songo_player.play_previous()
	
	if Input.is_action_just_pressed("back"):
		songo_player.stop()
		Controller.nav_back()
		#closing_container.emit()
		
func render_ui():
	update_play_time()
	
func play():
	songo_player.play_from_start()
	%PauseButton.grab_focus()
		
func setup_display_for(music_record: MusicRecord):
	%EndTimeLabel.text = "00:00" # gets updated later
	%TitleLabel.set_carousel_text(music_record.title)
	%ArtistLabel.set_carousel_text(music_record.artist)
	%AlbumLabel.set_carousel_text(music_record.album)
	
	var image_extractor = Mp3ImageExtractor.new()
	var image = image_extractor.get_cover_image(music_record.full_path)
	if image == null: image = songo_data.get_album_cover(music_record.album)
	if image == null:
		%MusicImage.hide()
	else:
		%MusicImage.show()
		%MusicImage.texture = ImageTexture.create_from_image(image)
	
	%FileTypeLabel.text = music_record.full_path.get_extension().to_upper() + " File"

func set_end_time(music_record: MusicRecord):
	var length_sec: float = music_record.raw_length
	
	if length_sec < 0: 
		%EndTimeLabel.text = "00:00"
		return
		
	current_song_duration = length_sec
	var minutes: int = int(length_sec) / 60
	var seconds: int = int(length_sec) % 60
	%EndTimeLabel.text = "%d:%02d" % [minutes, seconds]
	
func update_play_time():
	if songo_player.is_playing():
		var pos_sec: float = songo_player.get_playback_position()
		var minutes: int = int(pos_sec) / 60
		var seconds: int = int(pos_sec) % 60
		%CurrentTimeLabel.text = "%d:%02d" % [minutes, seconds]
		var progress_ratio = pos_sec / current_song_duration
		%ProgressLine.scale.x = progress_ratio
		
func setup_playlist_info():
	var next_song = songo_player.get_next_mp3_record()
	%NextSongTitle.text = next_song.title
	%PlaylistProgress.text = "%d / %d" % [songo_player.play_index+1, songo_player.music_files.size()]

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
	
func _on_started_new_song(music_record: MusicRecord):
	setup_display_for(music_record)
	set_end_time(music_record)
	setup_playlist_info()
	
func _on_play_button_pressed() -> void:
	songo_player.resume()
	display_play_button()

func _on_pause_button_pressed() -> void:
	songo_player.pause()
	display_pause_button()
