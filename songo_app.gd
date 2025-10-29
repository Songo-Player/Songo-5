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

var locked_inputs: bool = false
var showing_quick_menu: bool = false

var debug_press_count = 0

func _ready() -> void:
	var my_theme := load("res://songo_base_theme.tres")
	get_tree().root.theme = my_theme
	apply_theme_color()
	apply_ui_scale()
	Engine.physics_ticks_per_second = 0

	%VersionLabel.text = SongoDataResource.VERSION
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	add_debug_info()
	_update_widgets()
	get_tree().paused = false
	Engine.set_time_scale(1.0)
	get_tree().root.set_process(true)
	get_tree().root.set_process_input(true)


	Controller.content_body_node = %ContentBody
	Controller.nav_label_node = %NavLabel
	#Controller.exiting_overlay_node = %ExitingOverlay
	Controller.sfx_player = sfx_player
	Controller.songo_player = songo_player
	
	Controller.main_menu()
	call_deferred("network_check_display")
	
func network_check_display():
	var network_checker = NetworkStatus.new()
	print(%NetworkConnection)
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
func apply_ui_scale():
	var window = get_tree().get_root().get_window()
	window.content_scale_factor = songo_data.ui_scale
	
func apply_theme_color():
	var style = %MainColorPanel.get_theme_stylebox("panel").duplicate()
	style.bg_color = songo_data.theme_color
	%MainColorPanel.add_theme_stylebox_override("panel", style)

func _input(event: InputEvent) -> void:
	if showing_quick_menu:
		for action_event in InputMap.action_get_events("ui_right"):
			if event.is_match(action_event) and event.is_pressed():
				locked_inputs = not locked_inputs
				if locked_inputs == false:
					get_viewport().set_input_as_handled()
				break  # Stop after finding a match
		for action_event in InputMap.action_get_events("ui_left"):
			if event.is_match(action_event) and event.is_pressed():
				songo_data.apply_next_theme()
				apply_theme_color()
				break  # Stop after finding a match
		for action_event in InputMap.action_get_events("ui_up"):
			if event.is_match(action_event) and event.is_pressed():
				var window = get_tree().get_root().get_window()
				var current_ui_scale = window.content_scale_factor
				var new_scale = fmod(current_ui_scale + .05, 1.95) + .3
				window.content_scale_factor = new_scale
				songo_data.ui_scale = new_scale
				songo_data.save()
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
	else:
		showing_quick_menu = false
	%QuickMenu.visible = showing_quick_menu
	%LockedInputsLabel.visible = locked_inputs
	# Clean this up with signals
	%ScrapingLabel.visible = songo_data.scraping != 0.0
	%ScrapingLabel.text = "Scraping %.1f%%" % (clamp(songo_data.scraping, 0, 1.0) * 100)
		
	if Input.is_action_pressed("start") && Input.is_action_pressed("select"):
		Controller.quit_songo()
		
	if Controller.active_container: Controller.active_container.render_ui()
	
	if _is_any_target_action_pressed():
		debug_press_count += 1
		$ScreenIdleTimer.start()
		DeviceOS.wake_screen()
		
	if locked_inputs || showing_quick_menu: return
	
	if Input.is_action_just_pressed("start"):
		add_debug_info()
		%DebugInfo.visible = not %DebugInfo.visible
	
	if Input.is_action_just_pressed("L1"):
		if %DebugInfo.visible: 
			if DeviceOS.device_strategy is GenericLinuxStrategy:
				DeviceOS.set_device_os_strategy()
			else:
				DeviceOS.device_strategy = GenericLinuxStrategy.new()
			var new_strategy_name = DeviceOS.device_strategy.get_script().get_global_name()
			songo_data.preferred_device_strategy = new_strategy_name
			songo_data.save()
			add_debug_info()
		
	if Controller.active_container: Controller.active_container.handle_input(delta)

func _is_any_target_action_pressed() -> bool:
	var target_actions = ["ui_accept", "ui_left", "ui_right", "ui_up", "ui_down", "back", "Y"]
	for action in target_actions:
		if Input.is_action_pressed(action):
			return true
	return false
	
func get_time_string() -> String:
	var now = Time.get_datetime_dict_from_system()
	var hour_12 = now.hour % 12
	if hour_12 == 0: hour_12 = 12
	var hour = str(hour_12)
	var minute = str(now.minute).pad_zeros(2)
	return "%s:%s" % [hour, minute]
	
func add_debug_info():
	%OSNameLabel.text = "OS name: %s" % DeviceOS.get_os_name()
	%StrategyLabel.text = "Device OS Strategy: %s" % DeviceOS.device_strategy.get_script().get_global_name()
	%MusicDirLabel.text = "Saved Music Directory Path: %s" % songo_data.music_directory_path
	if DeviceOS.device_strategy.can_fade_screen:
		%BrightnessLabel.text = "Initial Brightness: %d" % DeviceOS.device_strategy.target_brightness
	%SongsImportedLabel.text = "Songs Imported: %d" % songo_data.music_records.size()
	%ImportLog.text = songo_data.summarized_import_notes()
	
func _on_screen_idle_timer_timeout() -> void:
	if Controller.active_container is SongPanelContainer:
		DeviceOS.start_screen_fade()
		$ScreenIdleTimer.stop()

func _on_focus_changed(control):
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
	%CurrentOsTime.text = get_time_string()
	if "get_battery_capacity" in DeviceOS.device_strategy:
		update_battery_async()
	else:
		%BatteryPercent.text = "N/A*"
