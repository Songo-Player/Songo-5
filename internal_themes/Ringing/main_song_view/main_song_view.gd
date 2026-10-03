extends MarginContainer

var current_song_duration = 1
var songo_data = SongoDataResource.get_instance()
var loaded_song = null
var panel_style

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	panel_style = %PanelContainer.get_theme_stylebox("panel")
	%PauseButton.grab_focus()
		
func setup():
	pass
	
func _process(_delta):
	update_play_time()
	%LockIcon.visible = DeviceOS.inputs_locked
	%StayAwakeIcon.visible = DeviceOS.keep_screen_awake
	
func setup_display_for(music_record: TagLibMusicRecord):
	display_play_button()
	
	%FileTypeLabel.text = "stream" if SongoPlayer.is_stream_record(music_record) else music_record.file_type

	if loaded_song == music_record.full_path: return

	if Artwork.song_cover_texture(music_record):
		%MusicImage.show()
		%MusicImage.texture = Artwork.song_cover_texture(music_record)
		%PanelContainer.remove_theme_stylebox_override("panel")
		%DefaultSongImage.hide()
	else:
		%DefaultSongImage.show()
		%MusicImage.hide()
		%PanelContainer.add_theme_stylebox_override("panel", panel_style)
		
	loaded_song = music_record.full_path
	set_end_time(music_record)
	setup_playlist_info()

func set_end_time(music_record: TagLibMusicRecord):
	var length_sec: float = music_record.raw_length
	
	if length_sec < 0: 
		current_song_duration = 0.0
		%EndTimeLabel.text = "00:00"
		return
		
	current_song_duration = length_sec
	var minutes: int = int(length_sec) / 60
	var seconds: int = int(length_sec) % 60
	%EndTimeLabel.text = "%d:%02d" % [minutes, seconds]
	
func update_play_time():
	if SongoPlayer.is_playing():
		var pos_sec: float = SongoPlayer.get_playback_position()
		var minutes: int = int(pos_sec) / 60
		var seconds: int = int(pos_sec) % 60
		%CurrentTimeLabel.text = "%d:%02d" % [minutes, seconds]
		var progress_ratio = pos_sec / current_song_duration if current_song_duration > 0 else 0.0
		%CircularProgressBar.progress = progress_ratio
		
func setup_playlist_info():
	%PlaylistProgress.text = "%d / %d" % [SongoPlayer.play_index+1, SongoPlayer.music_files.size()]

func display_play_button():
	%PlayButton.hide()
	%PauseButton.show()
	%PauseButton.grab_focus()
	
func display_pause_button():
	%PauseButton.hide()
	%PlayButton.show()
	%PlayButton.grab_focus()
	
func update_play_mode_icons():
	%PlaylistProgress.visible = SongoPlayer.play_mode == SongoPlayer.MODE.LINEAR && SongoPlayer.repeating == false
	%ShuffleIcon.visible = SongoPlayer.play_mode == SongoPlayer.MODE.SHUFFLE && SongoPlayer.repeating == false
	%RepeatingIcon.visible = SongoPlayer.repeating
	
##############################
#           SIGNALS          #
##############################

	
func _on_play_button_pressed() -> void:
	SongoPlayer.resume()
	display_play_button()

func _on_pause_button_pressed() -> void:
	SongoPlayer.pause()
	display_pause_button()

func _on_tree_entered() -> void:
	SongoPlayer.updated_repeat.connect(_on_updated_repeat)
	await get_tree().process_frame
	update_play_mode_icons()
	
func _on_tree_exited() -> void:
	SongoPlayer.updated_repeat.disconnect(_on_updated_repeat)
	
func _on_updated_repeat():
	update_play_mode_icons()
	setup_playlist_info()
