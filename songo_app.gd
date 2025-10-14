extends Control

@onready var my_label = $Label
@onready var songo_player = $SongoPlayer
@onready var sfx_player = $SfxPlayer
@onready var dark_out = %DarkOut

var directory_container
var song_panel_container
var all_songs_container
var albums_container
var active_container
var songo_data = SongoDataResource.get_instance()

var debug_press_count = 0

func _ready() -> void:
	var my_theme := load("res://songo_base_theme.tres")
	get_tree().root.theme = my_theme
	
	apply_theme_color()
	Engine.physics_ticks_per_second = 0
	%CurrentOsTime.text = get_time_string()
	setup_main_menu()
	if songo_data && songo_data.music_directory_path != null:
		songo_player.mp3_files = songo_data.mp3_records

	%VersionLabel.text = SongoDataResource.VERSION
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	add_debug_info()
	
	get_tree().paused = false
	Engine.set_time_scale(1.0)
	#get_tree().set_auto_accept_quit(false)
	get_tree().root.set_process(true)
	get_tree().root.set_process_input(true)
	#get_tree().set_pause_when_minimized(false)
	#get_tree().set_pause_when_unfocused(false)
	
func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: # Window lost focus (minimized or alt-tabbed)
		get_tree().paused = false
		get_tree().root.set_process(true)
		get_tree().root.set_process_input(true)
		Engine.time_scale = 1.0
		
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		get_tree().paused = false
		get_tree().root.set_process(true)
		get_tree().root.set_process_input(true)
		Engine.time_scale = 1.0
		
func apply_theme_color():
	var style = %MainColorPanel.get_theme_stylebox("panel").duplicate()
	style.bg_color = songo_data.theme_color
	%MainColorPanel.add_theme_stylebox_override("panel", style)
	
	var style_2 = %GradientFade.get_theme_stylebox("panel").duplicate()
	var target_color = Color(songo_data.theme_color)
	style_2.texture.gradient.colors[1] = Color(target_color, 0.0)
	style_2.texture.gradient.colors[0] = Color(target_color, 1.0)

	%GradientFade.add_theme_stylebox_override("panel", style_2)

func _process(delta: float) -> void:
	if "translate_inputs" in DeviceOS.device_strategy:
		DeviceOS.device_strategy.translate_inputs(delta)
		
	if _is_any_target_action_pressed():
		debug_press_count += 1
		$ScreenIdleTimer.start()
		DeviceOS.wake_screen()
	
	if Input.is_action_just_pressed("start"):
		add_debug_info()
		%DebugInfo.visible = not %DebugInfo.visible
		
	if Input.is_action_pressed("start") && Input.is_action_pressed("select"):
		_on_exit_menu_button_pressed()
		
	if active_container:
		active_container.render_ui()
		active_container.handle_input(delta)
	
	%GradientFade.visible = %MainMenu.visible == false

func _is_any_target_action_pressed() -> bool:
	var target_actions = ["ui_accept", "ui_left", "ui_right", "ui_up", "ui_down", "back"]
	for action in target_actions:
		if Input.is_action_pressed(action):
			return true
	return false
	
func _on_selected_dir(path):
	songo_data.music_directory_path = path
	songo_data.save()
	await get_tree().process_frame
	
	songo_data.index_mp3s()
	await songo_data.import_finished
	dark_out.hide()
	
	directory_container.queue_free()
	await get_tree().process_frame
	songo_player.mp3_files = songo_data.mp3_records
	setup_main_menu()
	
func get_time_string() -> String:
	var now = Time.get_datetime_dict_from_system()
	var hour = str(now.hour % 12).pad_zeros(2)
	var minute = str(now.minute).pad_zeros(2)
	return "%s:%s" % [hour, minute]

func setup_main_menu():
	%MainMenu.show()
	active_container = null
	await get_tree().process_frame
	%AllSongsMenuItem.get_child(0).grab_focus()
	%NavLabel.text = " > ".join(["Main Menu"])
	
func add_debug_info():
	%OSNameLabel.text = "OS name: %s" % DeviceOS.get_os_name()
	%StrategyLabel.text = "Device OS Strategy: %s" % DeviceOS.device_strategy.get_script().get_global_name()
	%MusicDirLabel.text = "Saved Music Directory Path: %s" % songo_data.music_directory_path
	if DeviceOS.device_strategy.can_fade_screen:
		%BrightnessLabel.text = "Initial Brightness: %d" % DeviceOS.device_strategy.target_brightness
	%SongsImportedLabel.text = "Songs Imported: %d" % songo_data.mp3_records.size()
	%ImportLog.text = songo_data.summarized_import_notes()
	
func _on_screen_idle_timer_timeout() -> void:
	if active_container is SongPanelContainer:
		DeviceOS.start_screen_fade()
		$ScreenIdleTimer.stop()
	#if active_container is not SongPanelContainer:
	#	$ScreenIdleTimer.stop()
	#	return
	#DeviceOS.start_screen_fade()

func _on_settings_menu_button_pressed() -> void:
	sfx_player.play_accept_sfx()
	%MainMenu.hide()
	directory_container = load("res://scenes/directory_container/directory_container.tscn").instantiate()
	directory_container.setup(dark_out)
	directory_container.selected_dir.connect(_on_selected_dir)
	directory_container.closing_container.connect(_back_to_main_menu)
	%ContentBody.add_child(directory_container)
	active_container = directory_container
	%NavLabel.text = " > ".join(["Main Menu", "Settings", "Directories"])

func _on_all_songs_menu_button_pressed() -> void:
	sfx_player.play_accept_sfx()
	if songo_player.mp3_files.size() == 0: return
	%MainMenu.hide()
	all_songs_container = load("res://scenes/all_songs_container/all_songs_container.tscn").instantiate()
	#all_songs_container.setup(songo_player, sfx_player)
	all_songs_container.all_songs_setup(songo_player, sfx_player)
	%ContentBody.add_child(all_songs_container)
	%NavLabel.text = " > ".join(["Main Menu", "All Songs"])
	active_container = all_songs_container
	all_songs_container.closing_container.connect(_back_to_main_menu)
	all_songs_container.opening_song_panel.connect(_on_opening_song_panel_from_all_songs)

func _on_opening_song_panel_from_all_songs(play_type):
	sfx_player.play_accept_sfx()
	$ScreenIdleTimer.start()
	all_songs_container.queue_free()
	song_panel_container = load("res://scenes/song_panel_container/song_panel_container.tscn").instantiate()
	song_panel_container.setup(songo_player)
	%ContentBody.add_child(song_panel_container)
	song_panel_container.closing_container.connect(func():
		song_panel_container.queue_free()
		_on_all_songs_menu_button_pressed()
		)
	active_container = song_panel_container
	song_panel_container.play()
	%NavLabel.text = " > ".join(["Main Menu", "All Songs", play_type])

func _back_to_main_menu():
	sfx_player.play_back_sfx()
	active_container.queue_free()
	setup_main_menu()
	DeviceOS.wake_screen()

func _on_exit_menu_button_pressed() -> void:
	sfx_player.play_accept_sfx()
	dark_out.show()
	%ExitingOverlay.show()
	await get_tree().process_frame
	get_tree().quit()

func _on_focus_changed(control):
	# Play navigation SFX only when valid focus change is accepted
	sfx_player.play_nav_sfx()

func _on_album_menu_button_pressed() -> void:
	sfx_player.play_accept_sfx()
	if songo_data.albums.size() == 0: return
	%MainMenu.hide()
	if (is_instance_valid(active_container)): active_container.queue_free()
	albums_container = load("res://scenes/albums_container/albums_container.tscn").instantiate()
	albums_container.setup(songo_player)
	%ContentBody.add_child(albums_container)
	%NavLabel.text = " > ".join(["Main Menu", "Albums"])
	active_container = albums_container
	albums_container.closing_container.connect(_back_to_main_menu)
	albums_container.opening_album.connect(_on_opening_album)
	#all_songs_container.opening_song_panel.connect(_on_opening_song_panel_from_all_songs)

func _on_opening_album(album_name):
	sfx_player.play_accept_sfx()
	if songo_player.mp3_files.size() == 0: return
	if is_instance_valid(albums_container): albums_container.queue_free()
	
	all_songs_container = load("res://scenes/all_songs_container/all_songs_container.tscn").instantiate()
	all_songs_container.album_setup(songo_player, sfx_player, album_name)
	%ContentBody.add_child(all_songs_container)
	%NavLabel.text = " > ".join(["Main Menu", "Albums", album_name])
	active_container = all_songs_container
	all_songs_container.closing_container.connect(_on_album_menu_button_pressed)
	all_songs_container.opening_song_panel.connect(func(play_type): 
		_on_opening_song_panel_from_album(play_type, album_name))
	
func _on_opening_song_panel_from_album(play_type, album_name):
	sfx_player.play_accept_sfx()
	all_songs_container.queue_free()
	song_panel_container = load("res://scenes/song_panel_container/song_panel_container.tscn").instantiate()
	song_panel_container.setup(songo_player)
	%ContentBody.add_child(song_panel_container)
	song_panel_container.closing_container.connect(func():
		song_panel_container.queue_free()
		_on_opening_album(album_name)
		)
	active_container = song_panel_container
	$ScreenIdleTimer.start()
	song_panel_container.play()
	%NavLabel.text = " > ".join(["Main Menu", "Albums", album_name, play_type])

func _on_u_iupdate_timer_timeout() -> void:
	%CurrentOsTime.text = get_time_string()
	#var text = "YES"
	#if get_window().has_focus() == false: text = "NO"
	#%BatteryPercent.text = text
