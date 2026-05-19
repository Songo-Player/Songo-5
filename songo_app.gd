extends Control

@onready var dark_out = %DarkOut

var directory_container
var song_panel_container
var all_songs_container
var albums_container
var active_container
var songo_data = SongoDataResource.get_instance()
var songo_settings = SongoSettings.get_instance()

var showing_quick_menu: bool = false

var debug_press_count = 0

func _ready() -> void:
	var my_theme := load("res://songo_base_theme.tres")
	get_tree().root.theme = my_theme
	Engine.physics_ticks_per_second = 1
	Engine.max_fps = 60
	ThemeManager.set_current_theme(songo_settings.theme_path)
	#if songo_settings.force_screen_fit == true:
		#UiHelper.apply_screen_fit()
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	if OS.get_environment("HIDE_MOUSE"): Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	add_debug_info()
	
	get_tree().paused = false
	Engine.set_time_scale(1.0)
	get_tree().root.set_process(true)
	get_tree().root.set_process_input(true)
	
	UiHelper.dark_out = %DarkOut
	UiHelper.app_message = %AppMessage
	UiHelper.main_color_panel = %MainColorPanel
	UiHelper.content_body = %ContentBody
	UiHelper.content_margin_container = %ContentMargin
	UiHelper.keyboard = %Keyboard
	UiHelper.flash_message_box = %FlashMessageBox
	UiHelper.vol_container = %VolumeContainer
	UiHelper.crt_overlay = %CrtOverlay
	UiHelper.the_grid_overlay = %TheGridOverlay
	UiHelper.apply_scale(songo_settings.ui_scale)
	UiHelper.apply_content_margin(songo_settings.content_margin)

	DeviceOS.fade_out_overlay = %FadeOutOverlay
	DeviceOS.setup_device_hallkey()

	Controller.content_body_node = %ContentBody
	SfxPlayer.set_vol(songo_settings.sfx_volume)
	
	Controller.main_menu()
	if songo_settings.auto_import && songo_data.music_directory_paths.size() > 0:
		songo_data.index_mp3s()
	if songo_settings.ab_layout_swapped:
		DeviceOS.swap_input_actions("back", "ui_accept")
	if songo_settings.xy_layout_swapped:
		DeviceOS.swap_input_actions("x", "Y")
	


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
	
func print_tree_path(node: Node):
	var path := []
	var current := node
	while current:
		path.push_front(current.name)
		current = current.get_parent()
	print("Path:", "/".join(path))
	
func _input(event: InputEvent) -> void:
	
	if false && event is InputEventMouseButton and event.pressed:
		var hovered := get_viewport().gui_get_hovered_control()

		if hovered:
			print("Clicked UI element:", hovered.name, " (", hovered.get_class(), ")")
			print_tree_path(hovered)
		else:
			print("Clicked: nothing")
			
	if showing_quick_menu:
		for action_event in InputMap.action_get_events("ui_up"):
			if event.is_match(action_event) and event.is_pressed():
				handle_playlist_quick_edit()
				break  # Stop after finding a match
				
		for action_event in InputMap.action_get_events("ui_down"):
			if event.is_match(action_event) and event.is_pressed():
				handle_queue_music()
				break  # Stop after finding a match
	
			
	if showing_quick_menu:
		get_viewport().set_input_as_handled()
	

		
func _process(delta: float) -> void:
	DeviceOS.device_strategy.translate_inputs(delta)
	if Input.is_action_pressed("Y"):
		showing_quick_menu = true
		update_quick_menu_vals()
	else:
		showing_quick_menu = false
		
	if Input.is_action_just_pressed("start") && Input.is_action_just_pressed("select"):
		DeviceOS.wake_screen()
		Controller.quit_songo()
		
	%QuickMenu.visible = showing_quick_menu
		
	if Controller.active_container: Controller.active_container.render_ui()
	
	if showing_quick_menu == true: return

	if Input.is_action_just_pressed("L2") && Input.is_action_just_pressed("R2"):
		%DebugInfo.visible = not %DebugInfo.visible
		if %DebugInfo.visible:
			add_debug_info()

	UiHelper.route_inputs(Controller.active_container, delta)

func handle_queue_music():
	if Controller.active_container is AllSongsContainer && SongoPlayerV2.is_playing():
		var queue_song = Controller.active_container.focused_song
		SongoPlayerV2.queue_music(queue_song)
		UiHelper.flash_message("Queued %s" % queue_song.title)

func get_playlist_target_song():
	if Controller.active_container is AllSongsContainer:
		return Controller.active_container.focused_song
	if Controller.active_container is ThemeMainSongView:
		return SongoPlayerV2.get_current_music_record()
	return null
	
func get_playlist_target_collection():
	if songo_data.recent_playlist == null: return null
	if "focused_collection" in Controller.active_container:
		return Controller.active_container.focused_collection
	else: return null
	
func update_quick_menu_vals():
	var actions_available = false
	var target_song = get_playlist_target_song()
	if target_song && songo_data.recent_playlist:
		actions_available = true
		%AddRemoveInPlaylistQuick.show()
		var new_text = ""
		if target_song in songo_data.recent_playlist.music_records:
			new_text = ": Remove song from %s" % songo_data.recent_playlist_name
		else:
			new_text = ": Add song to %s" % songo_data.recent_playlist_name	
		%AddRemoveInPlaylistLabel.text = new_text
	
	var target_collection = get_playlist_target_collection()
	if target_collection && songo_data.recent_playlist:
		actions_available = true
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

	if (target_collection == null && target_song == null) || songo_data.recent_playlist == null:
		%AddRemoveInPlaylistQuick.hide()
		
	if Controller.active_container is AllSongsContainer && target_song && SongoPlayerV2.is_playing():
		actions_available = true
		%QueueSong.show()
	else:
		%QueueSong.hide()
		
	%NoQuickMenuActions.visible = not actions_available

func handle_playlist_quick_edit():
	var target_collection = get_playlist_target_collection()
	if target_collection && songo_data.recent_playlist:
		var overlap = songo_data.recent_playlist.get_collection_overlap(target_collection.music_records)
		var handled_song_count = 0
		if overlap >= 0.5:
			handled_song_count = songo_data.recent_playlist.remove_tracks(target_collection.music_records)
			UiHelper.flash_message("%d songs removed from %s" % [handled_song_count, songo_data.recent_playlist.name])
		else:
			handled_song_count = songo_data.recent_playlist.add_tracks(target_collection.music_records)
			UiHelper.flash_message("%d songs added to %s" % [handled_song_count, songo_data.recent_playlist.name])

	var target_song = get_playlist_target_song()
	if target_song && songo_data.recent_playlist:
		if target_song in songo_data.recent_playlist.music_records:
			songo_data.recent_playlist.remove_track(target_song.full_path)
			UiHelper.flash_message("Song removed from %s" % songo_data.recent_playlist.name)
		else:
			songo_data.recent_playlist.add_track(target_song.full_path)
			UiHelper.flash_message("Song added to %s" % songo_data.recent_playlist.name)
	
	
func add_debug_info():
	%OSNameLabel.text = "OS name: %s" % DeviceOS.get_os_name()
	%DeviceIdLabel.text = "Device ID: %s" % OS.get_environment("DEVICE_NAME")
	%ScreenSize.text = "Screen Size: %s" % str(DisplayServer.screen_get_size())
	%WindowSize.text = "Window Size: %s" % str(DisplayServer.window_get_size())
	%DeviceOrientation.text = "Device Orientation: %s" % string_screen_orientation()
	%RootSize.text = "Root Size: %s" % str(get_parent().size)
	if DeviceOS.device_strategy.can_fade_screen:
		%BrightnessLabel.text = "Initial Brightness: %d" % DeviceOS.device_strategy.target_brightness

	
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

func _on_focus_changed(control):
	UiHelper.register_focus_change(control)
	SfxPlayer.play_nav_sfx()
