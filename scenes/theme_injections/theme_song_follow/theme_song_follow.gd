extends MarginContainer
class_name ThemeSongFollow

const DEFAULT_SCENE_PATH = "res://internal_themes/SongoClassic/song_follow/song_follow.tscn"
var theme_element: Control
var songo_settings = SongoSettings.get_instance()
var songo_data = SongoDataResource.get_instance()

func _ready() -> void:
	ThemeManager.theme_updated.connect(_setup_from_theme)
	SongoPlayerV2.started_new_song.connect(func(music_record):
		_on_started_new_song(music_record)
		)
	Controller.page_changed.connect(_on_page_change)


func _process(delta):
	if SongoPlayerV2.is_playing() && Controller.active_container is not ThemeMainSongView:
		handle_input(delta)
	
func setup():
	pass
	
func _setup_from_theme():
	if not ThemeManager.current_theme: return
	var new_element: Control
	if theme_element:
		theme_element.queue_free()
		theme_element = null
		await Engine.get_main_loop().process_frame
	if not SongoPlayerV2.is_playing(): return
	var theme_component_path = ThemeManager.get_scene_path('song_follow')
	if theme_component_path:
		new_element = load(theme_component_path).instantiate()
	else:
		new_element = load(DEFAULT_SCENE_PATH).instantiate()
	theme_element = new_element
	add_child(new_element)
	_on_started_new_song(SongoPlayerV2.get_current_music_record())
	
func handle_input(delta: float):
		if Input.is_action_just_pressed("L2"):
			var target_playback = SongoPlayerV2.get_playback_position() - float(songo_settings.seek_backward_time)
			SongoPlayerV2.ffmpeg_audio_playback.seek(max(target_playback, 0.0))
			
		if Input.is_action_just_pressed("R2"):
			var target_playback = SongoPlayerV2.get_playback_position() + float(songo_settings.seek_forward_time)
			var song_length = SongoPlayerV2.current_song.raw_length
			if song_length > 0.0: target_playback = min(target_playback, song_length)
			SongoPlayerV2.ffmpeg_audio_playback.seek(target_playback)
		
		if Input.is_action_just_pressed("L1"):
			var playback_position: float = SongoPlayerV2.get_playback_position()
			if playback_position >= 3.0:
				SongoPlayerV2.play_from_start()
			else:
				SongoPlayerV2.play_previous()
				
		if Input.is_action_just_pressed("R1"):
			SongoPlayerV2.play_next()
		
		if Input.is_action_just_pressed("start"):
			_kill_theme_element()
			Controller.stored_state = null
			SongoPlayerV2.stop()
			
		if Input.is_action_just_pressed("select"):
			Controller.restore_state()

func _kill_theme_element():
	if theme_element != null:
		theme_element.queue_free()
		theme_element = null
		
func _on_started_new_song(music_record: MusicRecord):
	if theme_element == null: return
	music_record.album_cover_texture = null
	var image = songo_data.get_album_cover(music_record.album)
	if image != null:
		music_record.album_cover_texture = ImageTexture.create_from_image(image)
	if music_record.album_cover_texture == null:
		music_record.album_cover_texture = music_record.image_texture
	if theme_element && 'setup_display_for' in theme_element:
		theme_element.setup_display_for(music_record)
	
func _on_page_change():
	if Controller.active_container is ThemeMainSongView:
		_kill_theme_element()
	elif SongoPlayerV2.is_playing() && theme_element == null:
		_setup_from_theme()
	else: return
