extends Control

@onready var my_label = $Label
@onready var sfx_player = $SfxPlayer
@onready var dark_out = %DarkOut

var directory_container
var song_panel_container
var all_songs_container
var albums_container
var active_container
var songo_data = SongoDataResource.get_instance()
var songo_settings = SongoSettings.get_instance()

var locked_inputs: bool = false
var showing_quick_menu: bool = false

var debug_press_count = 0

func _ready() -> void:
	var my_theme := load("res://songo_base_theme.tres")
	get_tree().root.theme = my_theme

	Engine.physics_ticks_per_second = 0
	
	#if songo_settings.force_screen_fit == true:
		#UiHelper.apply_screen_fit()
	%VersionLabel.text = SongoDataResource.VERSION
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

	#add_debug_info()
	
	get_tree().paused = false
	Engine.set_time_scale(1.0)
	get_tree().root.set_process(true)
	get_tree().root.set_process_input(true)
	
	UiHelper.dark_out = %DarkOut
	UiHelper.app_message = %AppMessage
	UiHelper.main_color_panel = %MainColorPanel
	UiHelper.mini_song_panel = %MiniSongPanel
	UiHelper.content_body = %ContentBody
	UiHelper.keyboard = %Keyboard
	UiHelper.flash_message_box = %FlashMessageBox
	UiHelper.current_os_time = %CurrentOsTime
	#UiHelper.debug_info = %DebugInfo
	_update_widgets()
	UiHelper.apply_theme_color(songo_settings.theme_color)
	UiHelper.apply_scale(songo_settings.ui_scale)
	DeviceOS.fade_out_overlay = %FadeOutOverlay

	Controller.content_body_node = %ContentBody
	Controller.nav_label_node = %NavLabel
	#Controller.exiting_overlay_node = %ExitingOverlay
	Controller.sfx_player = sfx_player
	
	Controller.main_menu()
	call_deferred("network_check_display")
	if songo_settings.auto_import && songo_data.music_directory_paths.size() > 0:
		songo_data.index_mp3s()
	%MiniSongPanel.setup()
	
func network_check_display():
	var network_checker = NetworkStatus.new()
	var network_connection_node = %NetworkConnection
	network_checker.status_checked.connect(func(connected):
		if connected: %NetworkConnection.show()
		)
	network_checker.is_connected_to_network()

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
		
func _input(event: InputEvent) -> void:
	if showing_quick_menu:
		for action_event in InputMap.action_get_events("ui_right"):
			if event.is_match(action_event) and event.is_pressed():
				locked_inputs = not locked_inputs
				if locked_inputs == false:
					get_viewport().set_input_as_handled()
				break  # Stop after finding a match
				
		for action_event in InputMap.action_get_events("ui_up"):
			if event.is_match(action_event) and event.is_pressed():
				handle_playlist_quick_edit()
				break  # Stop after finding a match
				
		for action_event in InputMap.action_get_events("ui_down"):
			if event.is_match(action_event) and event.is_pressed():
				handle_queue_music()
				break  # Stop after finding a match
	
	if locked_inputs:
		if _is_any_target_action_pressed():
			$ScreenIdleTimer.start()
			DeviceOS.wake_screen()
			
	if locked_inputs || showing_quick_menu:
		get_viewport().set_input_as_handled()
		
func _process(delta: float) -> void:
	DeviceOS.device_strategy.translate_inputs(delta)
	if Input.is_action_pressed("Y"):
		showing_quick_menu = true
		update_quick_menu_vals()
	else:
		showing_quick_menu = false
	%QuickMenu.visible = showing_quick_menu
	%LockedInputsLabel.visible = locked_inputs
	
	# Clean this up with signals
	if songo_data.scraping > 0.1 || (songo_data.importing && songo_data.import_step > 0):
		%ScrapingLabel.visible = true
		if songo_data.scraping != 0.0:
			%ScrapingLabel.text = "Scraping %.1f%%" % (clamp(songo_data.scraping, 0, 1.0) * 100)
		else:
			%ScrapingLabel.text = "Importing %d/2 %.1f%%" % [songo_data.import_step, (clamp(songo_data.import_progress, 0, 1.0) * 100)]
	else:
		%ScrapingLabel.visible = false
		
	if Controller.active_container: Controller.active_container.render_ui()
	
	if _is_any_target_action_pressed():
		debug_press_count += 1
		var pref_timer = songo_settings.song_sleep_timer
		if pref_timer > 0:
			if $ScreenIdleTimer.wait_time != pref_timer:
				$ScreenIdleTimer.wait_time = pref_timer
			$ScreenIdleTimer.start()
		DeviceOS.wake_screen()
		
	if locked_inputs || showing_quick_menu: return
	UiHelper.route_inputs(Controller.active_container, delta)

func handle_queue_music():
	if UiHelper.mini_song_panel.visible == false: return
	if Controller.active_container is AllSongsContainer:
		var queue_song = Controller.active_container.focused_song
		SongoPlayer.queue_music(queue_song)
		UiHelper.flash_message("Queued %s" % queue_song.title)

func get_playlist_target_song():
	if Controller.active_container is AllSongsContainer:
		return Controller.active_container.focused_song
	if Controller.active_container is SongPanelContainer:
		return SongoPlayer.get_current_music_record()
	return null
	
func get_playlist_target_collection():
	if songo_data.recent_playlist == null: return null
	if "focused_collection" in Controller.active_container:
		return Controller.active_container.focused_collection
	else: return null
	
func update_quick_menu_vals():
	var target_song = get_playlist_target_song()
	if target_song != null:
		%AddRemoveInPlaylistQuick.show()
		var new_text = ""
		if target_song in songo_data.recent_playlist.music_records:
			new_text = ": Remove song from %s" % songo_data.recent_playlist_name
		else:
			new_text = ": Add song to %s" % songo_data.recent_playlist_name	
		%AddRemoveInPlaylistLabel.text = new_text
	
	var target_collection = get_playlist_target_collection()
	if target_collection != null:
		var overlap = songo_data.recent_playlist.get_collection_overlap(target_collection.music_records)
		%AddRemoveInPlaylistQuick.show()
		var collection_type = "album"
		if target_collection is ArtistRecord:
			collection_type = "artist"
		
		var new_text = ""
		if overlap >= 0.5:
			new_text = ": Remove %s from %s" % [collection_type, songo_data.recent_playlist_name]
		else:
			new_text = ": Add %s to %s" % [collection_type, songo_data.recent_playlist_name]	
		%AddRemoveInPlaylistLabel.text = new_text

	if target_collection == null && target_song == null:
		%AddRemoveInPlaylistQuick.hide()
		
	if Controller.active_container is AllSongsContainer && target_song && UiHelper.mini_song_panel.visible:
		%QueueSong.show()
	else:
		%QueueSong.hide()

func handle_playlist_quick_edit():
	var target_collection = get_playlist_target_collection()
	if target_collection:
		var overlap = songo_data.recent_playlist.get_collection_overlap(target_collection.music_records)
		var handled_song_count = 0
		if overlap >= 0.5:
			handled_song_count = songo_data.recent_playlist.remove_tracks(target_collection.music_records)
			UiHelper.flash_message("%d songs removed from %s" % [handled_song_count, songo_data.recent_playlist.name])
		else:
			handled_song_count = songo_data.recent_playlist.add_tracks(target_collection.music_records)
			UiHelper.flash_message("%d songs added to %s" % [handled_song_count, songo_data.recent_playlist.name])

	var target_song = get_playlist_target_song()
	if target_song:
		if target_song in songo_data.recent_playlist.music_records:
			songo_data.recent_playlist.remove_track(target_song.full_path)
			UiHelper.flash_message("Song removed from %s" % songo_data.recent_playlist.name)
		else:
			songo_data.recent_playlist.add_track(target_song.full_path)
			UiHelper.flash_message("Song added to %s" % songo_data.recent_playlist.name)

func _is_any_target_action_pressed() -> bool:
	var target_actions = ["ui_accept", "ui_left", "ui_right", "ui_up", "ui_down", "back", "Y", "select"]
	for action in target_actions:
		if Input.is_action_pressed(action):
			return true
	return false
	
func get_time_string() -> String:
	var now = Time.get_datetime_dict_from_system()
	var hour_12 = now.hour % 12
	if hour_12 == 0: hour_12 = 12
	var hour = str(hour_12)
	if songo_settings.clock_24_hour: hour = now.hour
	var minute = str(now.minute).pad_zeros(2)
	return "%s:%s" % [hour, minute]
	
#func add_debug_info():
#	%OSNameLabel.text = "OS name: %s" % DeviceOS.get_os_name()
#	%ScreenSize.text = "Screen Size: %s" % str(DisplayServer.screen_get_size())
#	%WindowSize.text = "Window Size: %s" % str(DisplayServer.window_get_size())
#	%DeviceOrientation.text = "Device Orientation: %s" % string_screen_orientation()
#	%RootSize.text = "Root Size: %s" % str(get_parent().size)
#	if DeviceOS.device_strategy.can_fade_screen:
#		%BrightnessLabel.text = "Initial Brightness: %d" % DeviceOS.device_strategy.target_brightness

	
func string_screen_orientation():
	var orientation = DisplayServer.screen_get_orientation()
	var strings = [
		"SCREEN_LANDSCAPE",
		"SCREEN_PORTRAIT",
		"SCREEN_REVERSE_LANDSCAPE",
		"SCREEN_REVERSE_PORTRAIT",
		"SCREEN_SENSOR_LANDSCAPE",
		"SCREEN_SENSOR_PORTRAIT",
		"SCREEN_SENSOR"
	]
	return strings[orientation]
	
func _on_screen_idle_timer_timeout() -> void:
	if Controller.active_container is SongPanelContainer:
		DeviceOS.start_screen_fade()
		$ScreenIdleTimer.stop()

func _on_focus_changed(control):
	UiHelper.register_focus_change(control)
	sfx_player.play_nav_sfx()

func update_battery_async() -> void:
	var thread := Thread.new()
	thread.start(Callable(self, "_thread_get_battery"))
	
func _thread_get_battery():
	var result := ""
	result = str(DeviceOS.device_strategy.get_battery_capacity()) + "%"
	call_deferred("_update_battery_ui", result)
	
func _update_battery_ui(text: String) -> void:
	%BatteryPercent.text = text

func _on_ui_update_timer_timeout() -> void:
	_update_widgets()

func _update_widgets():
	#%CurrentOsTime.text = get_time_string()
	UiHelper.update_os_time()
	if "get_battery_capacity" in DeviceOS.device_strategy:
		update_battery_async()
	else:
		%BatteryPercent.text = "N/A*"
