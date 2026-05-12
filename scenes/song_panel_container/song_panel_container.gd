extends VBoxContainer

class_name SongPanelContainer

var current_song_duration = 1
var songo_data = SongoDataResource.get_instance()
var songo_settings = SongoSettings.get_instance()
var loaded_song = null
var inputs_locked = false
var panel_style

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	panel_style = %PanelContainer.get_theme_stylebox("panel")
	%PauseButton.grab_focus()
	try_wake()

func _input(event: InputEvent) -> void:
	if inputs_locked:
		get_viewport().set_input_as_handled()
		
func setup():
	pass
	
func handle_input(delta: float):
	if Input.is_action_just_pressed("start"):
		match songo_settings.start_btn_behavior:
			SongoSettings.START_BEHAVIOR.LOCK:
				inputs_locked = not inputs_locked
				try_wake()
				
			SongoSettings.START_BEHAVIOR.SLEEP:
				if DeviceOS.sleeping: try_wake()
				else: try_sleep()
			
			SongoSettings.START_BEHAVIOR.LOCK_SLEEP:
				inputs_locked = not inputs_locked
				if inputs_locked: try_sleep()
				else: try_wake()
				
			SongoSettings.START_BEHAVIOR.KEEP_AWAKE:
				DeviceOS.keep_screen_awake = not DeviceOS.keep_screen_awake
				try_wake()
				
	if _is_any_target_action_pressed(): try_wake()
	
	if inputs_locked: return
	if Input.is_action_just_pressed("ui_right") || Input.is_action_just_pressed("R1"):
		SongoPlayerV2.play_next()
		display_play_button()
	
	if Input.is_action_just_pressed("ui_left") || Input.is_action_just_pressed("L1"):
		var playback_position: float = SongoPlayerV2.get_playback_position()
		display_play_button()
		if playback_position >= 3.0:
			SongoPlayerV2.play_from_start()
		else:
			SongoPlayerV2.play_previous()
	
	if Input.is_action_just_pressed("back"):
		if SongoPlayerV2.is_playing():
			Controller.save_state()
			UiHelper.show_mini_song_panel()
		else:
			SongoPlayerV2.stop()
		Controller.new_nav_back()
	
	if SongoPlayerV2.is_playing():
		if Input.is_action_just_pressed("ui_up") || Input.is_action_just_pressed("L2"):
			var target_playback = SongoPlayerV2.get_playback_position() - float(songo_settings.seek_backward_time)
			SongoPlayerV2.ffmpeg_audio_playback.seek(max(target_playback, 0.0))
			
		if Input.is_action_just_pressed("ui_down") || Input.is_action_just_pressed("R2"):
			var target_playback = SongoPlayerV2.get_playback_position() + float(songo_settings.seek_forward_time)
			var song_length = SongoPlayerV2.current_song.raw_length
			if song_length > 0.0: target_playback = min(target_playback, song_length)
			SongoPlayerV2.ffmpeg_audio_playback.seek(target_playback)

func render_ui():
	%LockIcon.visible = inputs_locked
	%StayAwakeIcon.visible = DeviceOS.keep_screen_awake
	update_play_time()


func play():
	SongoPlayerV2.play_from_start()
	_on_started_new_song(SongoPlayerV2.get_current_music_record())
	%PauseButton.grab_focus()
	
		
func setup_display_for(music_record: MusicRecord):
	%EndTimeLabel.text = "00:00" # gets updated later
	%TitleLabel.set_carousel_text(music_record.title)
	%ArtistLabel.set_carousel_text(music_record.artist)
	%AlbumLabel.set_carousel_text(music_record.album)
	
	%FileTypeLabel.text = music_record.full_path.get_extension().to_upper() + " File"

	if loaded_song == music_record.full_path: return
	
	var image_texture = null

	var image = songo_data.get_album_cover(music_record.album)
	if image != null:
		image_texture = ImageTexture.create_from_image(image)
	if image_texture == null:
		image_texture = music_record.image_texture

	if image_texture:
		%MusicImage.show()
		%MusicImage.texture = image_texture
		%PanelContainer.remove_theme_stylebox_override("panel")
		%DefaultSongImage.hide()
	else:
		%DefaultSongImage.show()
		%MusicImage.hide()
		%PanelContainer.add_theme_stylebox_override("panel", panel_style)
		
	loaded_song = music_record.full_path

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
	if SongoPlayerV2.is_playing():
		var pos_sec: float = SongoPlayerV2.get_playback_position()
		var minutes: int = int(pos_sec) / 60
		var seconds: int = int(pos_sec) % 60
		%CurrentTimeLabel.text = "%d:%02d" % [minutes, seconds]
		var progress_ratio = pos_sec / current_song_duration
		%ProgressLine.scale.x = progress_ratio
	
func try_sleep():
	if SongoPlayerV2.is_playing():
		if DeviceOS.fade_tween: 
			try_wake()
			return
		DeviceOS.start_screen_fade()
		$ScreenIdleTimer.stop()
	else:
		UiHelper.flash_message("Can't start screen sleep unless playing music.")

func try_wake():
	var pref_timer = songo_settings.song_sleep_timer
	if pref_timer > 0:
		if $ScreenIdleTimer.wait_time != pref_timer:
			$ScreenIdleTimer.wait_time = pref_timer
		$ScreenIdleTimer.start()
		DeviceOS.wake_screen()
		
func setup_playlist_info():
	var next_song = SongoPlayerV2.get_next_mp3_record()
	%NextSongTitle.text = next_song.title
	%PlaylistProgress.text = "%d / %d" % [SongoPlayerV2.play_index+1, SongoPlayerV2.music_files.size()]

func display_play_button():
	%PlayButton.hide()
	%PauseButton.show()
	%PauseButton.grab_focus()
	
func display_pause_button():
	%PauseButton.hide()
	%PlayButton.show()
	%PlayButton.grab_focus()
	
func update_play_mode_icons():
	%PlaylistProgress.visible = SongoPlayerV2.play_mode == SongoPlayerV2.MODE.LINEAR && SongoPlayerV2.repeating == false
	%ShuffleIcon.visible = SongoPlayerV2.play_mode == SongoPlayerV2.MODE.SHUFFLE && SongoPlayerV2.repeating == false
	%RepeatingIcon.visible = SongoPlayerV2.repeating
	
##############################
#           SIGNALS          #
##############################
	
func _on_started_new_song(music_record: MusicRecord):
	setup_display_for(music_record)
	set_end_time(music_record)
	setup_playlist_info()
	
func _on_play_button_pressed() -> void:
	SongoPlayerV2.resume()
	display_play_button()

func _on_pause_button_pressed() -> void:
	SongoPlayerV2.pause()
	display_pause_button()


func _on_tree_entered() -> void:
	UiHelper.hide_mini_song_panel()
	_on_started_new_song(SongoPlayerV2.get_current_music_record())
	SongoPlayerV2.started_new_song.connect(_on_started_new_song)
	SongoPlayerV2.updated_repeat.connect(_on_updated_repeat)
	await get_tree().process_frame
	update_play_mode_icons()
	
	#var song = SongoPlayerV2.get_current_music_record()
	#if song: _on_started_new_song(song)

func _on_tree_exited() -> void:
	SongoPlayerV2.started_new_song.disconnect(_on_started_new_song)
	SongoPlayerV2.updated_repeat.disconnect(_on_updated_repeat)
	
func _on_updated_repeat():
	update_play_mode_icons()
	setup_playlist_info()

func _is_any_target_action_pressed() -> bool:
	if inputs_locked:
		return false #Input.is_action_just_pressed("start")
		
	var target_actions = ["ui_accept", "ui_left", "ui_right", "ui_up", "ui_down", "back", "Y", "select", "L1", "R1", "L2", "R2"]
	for action in target_actions:
		if Input.is_action_pressed(action):
			return true
	return false

func _on_screen_idle_timer_timeout() -> void:
	if SongoPlayerV2.is_playing():
		if DeviceOS.keep_screen_awake:
			$ScreenIdleTimer.start()
		else:
			DeviceOS.start_screen_fade()
			$ScreenIdleTimer.stop()
