extends Node

signal pseudo_sleep
signal pseudo_sleep_wake

var fade_out_overlay: Control

#var songo_data = SongoDataResource.get_instance()
var songo_settings = SongoSettings.get_instance()
var battery_info_path = "" # Set only when a battery was found, themes check this before showing it
# CHAI (Common Handheld Application Interface). Brightness, battery and idle
# suppression all go through the "chai" command. The CFW may ship it, or the
# launcher puts a retrofit on PATH (chai_retrofit/chai_entry.sh); either way
# it's just "chai".
var chai_available = false
# Screen Brightness Adjustments
var fade_val: float
var fade_tween = null
var sleeping: bool = false
var keep_screen_awake = false
var inputs_locked = false
var device_name = ""
var no_bright_fade_available = false
var target_brightness = 155

func _init():
	chai_available = OS.get_name() != "Android" && OS.execute("sh", ["-c", "command -v chai"]) == 0
	set_battery_info_path()
	device_name = OS.get_environment("DEVICE_NAME")
	set_backlight_info()

## Runs a chai command and returns its trimmed output, "" without chai
func run_chai(args: Array) -> String:
	if !chai_available: return ""
	var output = []
	OS.execute("chai", args, output)
	return output[0].strip_edges() if output.size() > 0 else ""

## Starts a chai command without waiting for it
func spawn_chai(args: Array) -> void:
	if !chai_available: return
	OS.create_process("chai", args)

## A chai command as one shell command line, for things that run it later
## through sh -c (eg: the music daemon's exit hook). "" without chai.
func chai_shell_command(args: Array) -> String:
	if !chai_available: return ""
	var parts = ["chai"] + args
	return " ".join(parts.map(func(part): return "'%s'" % str(part).replace("'", "'\\''")))

func set_backlight_info():
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
	


# Idle suppression (chai set-idle-suppression) follows playback, so the CFW
# doesn't dim, sleep, or suspend on lid close while music plays
func setup_device_hallkey():
	if !chai_available: return
	printerr("INFO: CHAI idle suppression enabled")
	SongoPlayer.music_started.connect(_on_music_started)
	SongoPlayer.music_stopped.connect(_on_music_stopped)
	

func start_screen_fade():
	if UiHelper.overlay_window && UiHelper.overlay_window.visible: return # Controls are locked in this state
	if sleeping: return #Possibly manually put to sleep
	
	var result = run_chai(["get-brightness"])
	if result.is_valid_int():
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
		run_chai(["set-brightness", str(level)])

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
	if OS.get_name() == "Android":
		set_android_battery_info_path()
		return

	# Trust the launcher's chai instead of running it here, which would block
	# startup on a shell. get-battery-percent prints nothing when it can't find
	# a battery, so headers treat an empty capacity as "no battery".
	battery_info_path = "chai" if chai_available else ""

# Android has no battery scripts, read the kernel's power_supply node directly.
# Some ROMs block apps from reading sysfs, in which case battery_info_path stays empty.
func set_android_battery_info_path():
	var power_supply_dir = "/sys/class/power_supply"
	var candidates = ["battery"]
	var dir = DirAccess.open(power_supply_dir)
	if dir:
		for entry in dir.get_directories():
			if entry != "battery" && read_sysfs_value("%s/%s/type" % [power_supply_dir, entry]) == "Battery":
				candidates.append(entry)

	for candidate in candidates:
		var candidate_path = "%s/%s" % [power_supply_dir, candidate]
		if read_sysfs_value(candidate_path + "/capacity") != "":
			battery_info_path = candidate_path
			return

func read_sysfs_value(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	return file.get_as_text().strip_edges()

func get_battery_info(info_key: String):
	if OS.get_name() == "Android":
		return get_android_battery_info(info_key)

	match info_key:
		"capacity":
			return run_chai(["get-battery-percent"])
		"status":
			# chai only reports 1 (charging) or 0 (anything else)
			return "Charging" if run_chai(["get-battery-status"]) == "1" else "Not charging"
		_:
			print("Unkown battery info key: %s" % info_key)
			return ""

func get_android_battery_info(info_key: String):
	if battery_info_path == "": return ""
	match info_key:
		"capacity":
			return read_sysfs_value(battery_info_path + "/capacity")
		"status":
			# sysfs reports Charging, Discharging, Not charging, Full or Unknown
			return "Charging" if read_sysfs_value(battery_info_path + "/status") == "Charging" else "Not charging"
		_:
			print("Unkown battery info key: %s" % info_key)
			return ""

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

# Last binding added per action through set_action_binding, so it can be replaced
var _bound_events := {}

func apply_action_bindings() -> void:
	var settings := SongoSettings.get_instance()
	var actions := SongoSettings.ACTION_BINDINGS.keys()
	for action in actions:
		var others := actions.filter(func(a): return a != action)
		set_action_binding(action, settings.get(SongoSettings.ACTION_BINDINGS[action]), others)

func set_action_binding(action: String, binding: InputEvent, other_actions: Array = []) -> void:
	# Replaces the action's joypad button/axis and previous custom binding,
	# default keyboard/mouse events are left alone
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			InputMap.action_erase_event(action, event)
	if _bound_events.has(action) && InputMap.action_has_event(action, _bound_events[action]):
		InputMap.action_erase_event(action, _bound_events[action])
	# Don't let one input fire two actions (e.g. Enter bound to back)
	for other_action in other_actions:
		for event in InputMap.action_get_events(other_action):
			if event.is_match(binding):
				InputMap.action_erase_event(other_action, event)
	InputMap.action_add_event(action, binding)
	_bound_events[action] = binding
	
func _on_music_started():
	spawn_chai(["set-idle-suppression", "1"])

func _on_music_stopped():
	spawn_chai(["set-idle-suppression", "0"])
	
		
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
