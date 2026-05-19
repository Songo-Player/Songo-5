extends MarginContainer
class_name ThemeMainSongView

const DEFAULT_SCENE_PATH = "res://internal_themes/SongoClassic/main_song_view/main_song_view.tscn"
var theme_element: Control
var songo_settings = SongoSettings.get_instance()
var songo_data = SongoDataResource.get_instance()

func _ready() -> void:
	ThemeManager.theme_updated.connect(_setup_from_theme)
	_setup_from_theme()
	try_wake()

func setup():
	pass
	
func _setup_from_theme():
	if not ThemeManager.current_theme: return
	var new_element: Control
	if theme_element:
		theme_element.queue_free()
		await Engine.get_main_loop().process_frame
	var theme_background_root_path = ThemeManager.get_scene_path('main_song_view')
	if theme_background_root_path:
		new_element = load(theme_background_root_path).instantiate()
	else:
		new_element = load(DEFAULT_SCENE_PATH).instantiate()
	theme_element = new_element
	add_child(new_element)
	_on_started_new_song(SongoPlayerV2.get_current_music_record())
	
func _input(event: InputEvent) -> void:
	if DeviceOS.inputs_locked:
		get_viewport().set_input_as_handled()
		
func handle_input(delta: float):
	if Input.is_action_just_pressed("start"):
		match songo_settings.start_btn_behavior:
			SongoSettings.START_BEHAVIOR.LOCK:
				DeviceOS.inputs_locked = not DeviceOS.inputs_locked
				try_wake()
				
			SongoSettings.START_BEHAVIOR.SLEEP:
				if DeviceOS.sleeping: try_wake()
				else: try_sleep()
			
			SongoSettings.START_BEHAVIOR.LOCK_SLEEP:
				DeviceOS.inputs_locked = not DeviceOS.inputs_locked
				if DeviceOS.inputs_locked: try_sleep()
				else: try_wake()
				
			SongoSettings.START_BEHAVIOR.KEEP_AWAKE:
				DeviceOS.keep_screen_awake = not DeviceOS.keep_screen_awake
				try_wake()
				
	if _is_any_target_action_pressed(): try_wake()
	
	if DeviceOS.inputs_locked: return
	
	if Input.is_action_just_pressed("x"):
		SongoPlayerV2.setRepeating(!SongoPlayerV2.repeating)
	
	if Input.is_action_just_pressed("ui_right") || Input.is_action_just_pressed("R1"):
		SongoPlayerV2.play_next()
		#display_play_button()
	
	if Input.is_action_just_pressed("ui_left") || Input.is_action_just_pressed("L1"):
		var playback_position: float = SongoPlayerV2.get_playback_position()
		#display_play_button()
		if playback_position >= 3.0:
			SongoPlayerV2.play_from_start()
		else:
			SongoPlayerV2.play_previous()
	
	if Input.is_action_just_pressed("back"):
		if SongoPlayerV2.is_playing() && songo_settings.song_following:
			Controller.save_state()
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
	pass
	
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
		
func _is_any_target_action_pressed() -> bool:
	if DeviceOS.inputs_locked:
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
			
func _on_started_new_song(music_record: MusicRecord):
	music_record.album_cover_texture = null
	var image = songo_data.get_album_cover(music_record.album)
	if image != null:
		music_record.album_cover_texture = ImageTexture.create_from_image(image)
	if music_record.album_cover_texture == null:
		music_record.album_cover_texture = music_record.image_texture
	if theme_element && 'setup_display_for' in theme_element:
		theme_element.setup_display_for(music_record)
	
func _on_tree_entered() -> void:
	# Might need to move this after the await
	if is_node_ready():
		_on_started_new_song(SongoPlayerV2.get_current_music_record())
	SongoPlayerV2.started_new_song.connect(_on_started_new_song)
	
func _on_tree_exited() -> void:
	SongoPlayerV2.started_new_song.disconnect(_on_started_new_song)
