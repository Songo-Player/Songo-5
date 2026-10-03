extends Node

signal pseudo_sleep
signal pseudo_sleep_wake

var fade_out_overlay: Control

var songo_data = SongoDataResource.get_instance()
var songo_settings = SongoSettings.get_instance()
var battery_info_path = "" # Set only when a battery was found, themes check this before showing it
var battery_percent_path = ""
var charging_path = ""
# Screen Brightness Adjustments
var fade_val: float
var fade_tween = null
var sleeping: bool = false
var keep_screen_awake = false
var inputs_locked = false
var device_name = ""
var hallkey_path = false
var set_brightness_path = ""
var get_brightness_path = ""
var set_playback_suppressions_path = ""
var remove_playback_suppressions_path = ""
var no_bright_fade_available = false
var target_brightness = 155

func _init():
	set_battery_info_path()
	device_name = OS.get_environment("DEVICE_NAME")
	set_backlight_info()
	

func set_backlight_info():
	set_brightness_path = OS.get_environment("SONGO_SET_BRIGHTNESS_PATH")
	get_brightness_path = OS.get_environment("SONGO_GET_BRIGHTNESS_PATH")
	var env_no_fade = OS.get_environment("NO_BRIGHT_FADE_AVAILABLE")
	if (env_no_fade && env_no_fade != ''):
		no_bright_fade_available = env_no_fade == '1'
	else:
		no_bright_fade_available = true
	
	if no_bright_fade_available:
		print("No bright fade available")
		
func _process(_delta: float) -> void:
	if fade_tween != null && songo_settings.song_sleep_type == 0:
		set_backlight(int(round(fade_val)))

func get_os_name():
	var initial_name = OS.get_name()
	var post_fix_name = OS.get_environment("CFW_NAME")
	if post_fix_name:
		return "%s - (%s)" % [initial_name, post_fix_name]
	else:
		return initial_name
	


func setup_device_hallkey():

	set_playback_suppressions_path = OS.get_environment("SET_PLAYBACK_SUPPRESSIONS_PATH")
	remove_playback_suppressions_path = OS.get_environment("REMOVE_PLAYBACK_SUPPRESSIONS_PATH")
	
	printerr("INFO: Supression paths: [%s, %s]" % [set_playback_suppressions_path, remove_playback_suppressions_path])
	SongoPlayer.music_started.connect(_on_music_started)
	SongoPlayer.music_stopped.connect(_on_music_stopped)
	

func start_screen_fade():
	if UiHelper.overlay_window && UiHelper.overlay_window.visible: return # Controls are locked in this state
	if sleeping: return #Possibly manually put to sleep
	
	var output = []
	var exit_code = OS.execute("sh", ["-c", get_brightness_path], output)
	var result = output[0].strip_edges() if output.size() > 0 else ""
	if result != "":
		target_brightness = int(result)
	await Engine.get_main_loop().process_frame
		
	match songo_settings.song_sleep_type:
		0:
			if no_bright_fade_available == true:
				songo_settings.song_sleep_type = 1 # This should really be an enum
				return
			fade_tween = create_tween()
			fade_val = target_brightness
			fade_tween.tween_property(self, "fade_val", 0.0, 2.0) # fade over 2 seconds
			fade_tween.finished.connect(Callable(self, "_on_tween_fade_finished"))
		1:
			fade_out_overlay.modulate.a = 0.0
			fade_tween = create_tween()
			fade_tween.tween_property(fade_out_overlay, "modulate:a", 1.0, 2.0)
			fade_tween.finished.connect(Callable(self, "_on_tween_fade_finished"))
		2: 
			return
		_:
			UiHelper.flash_message("Error: Unknown screen fade attempt.")

func _on_tween_fade_finished():
	fade_tween.kill()
	fade_tween = null
	sleeping = true
	await get_tree().process_frame
	if songo_settings.song_sleep_type == 0:
		set_backlight(0)
	fade_out_overlay.modulate.a = 1.0
	pseudo_sleep.emit()
	
func set_backlight(level: int):
	if songo_settings.song_sleep_type == 0:
		var cmd = "%s %d" % [set_brightness_path, level]
		OS.execute("sh", ["-c", cmd])

func wake_screen():
	if sleeping == true || fade_tween != null:
		if fade_tween != null: 
			fade_tween.kill()
			fade_tween = null

		if no_bright_fade_available == false:
			set_backlight(target_brightness)
			
		fade_out_overlay.modulate.a = 0.0
		sleeping = false
	pseudo_sleep_wake.emit()
		
func set_battery_info_path():
	battery_percent_path = OS.get_environment("SONGO_GET_BATTERY_PERCENT_PATH")
	charging_path = OS.get_environment("SONGO_GET_CHARGING_PATH")

	# The percent script prints nothing when it can't find a battery
	if run_battery_script(battery_percent_path) != "":
		battery_info_path = battery_percent_path

func get_battery_info(info_key: String):
	match info_key:
		"capacity":
			return run_battery_script(battery_percent_path)
		"status":
			# The charging script only reports 1 (charging) or 0 (anything else)
			return "Charging" if run_battery_script(charging_path) == "1" else "Not charging"
		_:
			print("Unkown battery info key: %s" % info_key)
			return ""

func run_battery_script(path: String) -> String:
	if path == "": return ""
	var output = []
	OS.execute("sh", [path], output)
	return output[0].strip_edges() if output.size() > 0 else ""

func swap_input_actions(action_a: String, action_b: String) -> void:
	# Get current events
	var events_a := InputMap.action_get_events(action_a)
	var events_b := InputMap.action_get_events(action_b)

	# Clear both actions
	InputMap.action_erase_events(action_a)
	InputMap.action_erase_events(action_b)

	# Reassign swapped events (duplicate to avoid shared references)
	for event in events_a:
		InputMap.action_add_event(action_b, event.duplicate(true))

	for event in events_b:
		InputMap.action_add_event(action_a, event.duplicate(true))
	
func _on_music_started():
	if set_playback_suppressions_path != "" && set_playback_suppressions_path != null:
		OS.create_process(set_playback_suppressions_path, [])
		
func _on_music_stopped():
	if remove_playback_suppressions_path != "" && remove_playback_suppressions_path != null:
		OS.create_process(remove_playback_suppressions_path, [])
	
		
var initial_delay := 0.5   # seconds to wait before first repeat
var timer := 0.0
var held_action := ""
var idle := true

func translate_inputs(delta):
	var action_name = ""
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP):
		action_name = "ui_up"
	elif Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN):
		action_name = "ui_down"

	if action_name == "":
		idle = true
		held_action = ""
		timer = 0.0
		return

	# First input after idle fires immediately
	if idle or held_action != action_name:
		held_action = action_name
		timer = 0.0
		idle = false
		return

	# Held input: wait initial delay, then fire every frame
	timer += delta
	if timer >= initial_delay:
		fake_input(action_name)
	
func fake_input(action_name):
	var a = InputEventAction.new()
	a.action = action_name
	a.pressed = true
	Input.parse_input_event(a)
	
	var b = InputEventAction.new()
	b.action = action_name
	b.pressed = false
	Input.parse_input_event(b)
