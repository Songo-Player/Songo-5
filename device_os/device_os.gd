extends Node

const CFW_MUOS = "muOS"
const CFW_KNULLI = "knulli"
const CFW_ROCKNIX = "ROCKNIX"
const CFW_TRIM_UI = "TrimUI"

var fade_out_overlay: Control
var device_strategy: DeviceOsStrategy
var device_strategy_name: get = get_device_strategy_name
var music_dir_tip: get = get_music_dir_tip
var songo_data = SongoDataResource.get_instance()
var songo_settings = SongoSettings.get_instance()
var battery_info_path = ""
# Screen Brightness Adjustments
var fade_val: float
var fade_tween = null
var sleeping: bool = false
var keep_screen_awake = false
var device_name = ""
var hallkey_path = false
var bin_path = ""

const HALLKEY_PATHS = {
	"/boot/boot/batocera.board.capability": "/batocera_board_capability_override",
	"/sys/class/power_supply/axp2202-battery/hallkey": "/hall_override/hallkey", # Rg35xx-SP, RG34xx-SP (muos Confirmed)
	"/sys/devices/platform/hall-mh248/hallvalue": "/hall_override/hallkey" # Miyoo Flip
}

func _init():
	#Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	set_device_os_strategy()
	set_battery_info_path()
	device_name = OS.get_environment("DEVICE_NAME")
	bin_path = OS.get_environment("SONGO_BINARIES_DIR")
	
	
func _process(delta: float) -> void:
	if fade_tween != null && songo_settings.song_sleep_type == 0:
		set_backlight(int(round(fade_val)))
	
func get_device_strategy_name():
	if device_strategy:
		return device_strategy.get_script().get_global_name()
	else:
		return "None"

func get_music_dir_tip():
	if device_strategy:
		return device_strategy.music_dir_tip
	else:
		return "Looks like you're using unsupported CFW, good luck!"

func get_os_name():
	var initial_name = OS.get_name()
	var post_fix_name = OS.get_environment("CFW_NAME")
	if post_fix_name:
		return "%s - (%s)" % [initial_name, post_fix_name]
	else:
		return initial_name
	
func get_valid_os_strategy():
	if WindowsStrategy.being_used():
		return WindowsStrategy
	elif MuosStrategy.being_used():
		return MuosStrategy
	elif KnulliStrategy.being_used():
		return KnulliStrategy
	elif RocknixStrategy.being_used():
		return RocknixStrategy
	elif NextUIStrategy.being_used():
		return NextUIStrategy
	return null
	
func set_device_os_strategy():
	if songo_settings.use_generic_strategy == true:
		device_strategy = GenericLinuxStrategy.new()
		return

	var valid_strategy = get_valid_os_strategy().new()
	if valid_strategy: device_strategy = valid_strategy
	else: device_strategy = GenericLinuxStrategy.new()
	
func setup_device():
	for target_path in HALLKEY_PATHS.keys():
		if FileAccess.file_exists(target_path):
			hallkey_path = target_path
			break
			
	if hallkey_path:
		SongoPlayerV2.music_started.connect(_on_music_started)
		SongoPlayerV2.music_stopped.connect(_on_music_stopped)

func start_screen_fade():
	if device_strategy.dynamic_brightness:
		device_strategy.set_initial_brightness()
		await Engine.get_main_loop().process_frame
		
	match songo_settings.song_sleep_type:
		0:
			if device_strategy.can_fade_screen == false:
				UiHelper.flash_message("Error: 'Bright Fade' attempted on unsupported cfw.")
				return
			fade_tween = create_tween()
			fade_val = device_strategy.target_brightness
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
	if device_strategy.can_fade_screen:
		set_backlight(0)
		fade_out_overlay.modulate.a = 0.0
	else:
		fade_out_overlay.modulate.a = 1.0
	
func set_backlight(level: int):
	if "set_backlight" in device_strategy:
		device_strategy.set_backlight(level)

func wake_screen():
	if sleeping == true || fade_tween != null:
		if fade_tween != null: 
			fade_tween.kill()
			fade_tween = null

		if device_strategy.can_fade_screen:
			set_backlight(device_strategy.target_brightness)
			
		fade_out_overlay.modulate.a = 0.0
		sleeping = false
		
func set_battery_info_path():
	var likely_paths = [
		"/sys/class/power_supply/axp2202-battery/",
		"/sys/class/power_supply/battery/",
	]
	for path in likely_paths:
		if DirAccess.dir_exists_absolute(path):
			battery_info_path = path
			break
	
func get_battery_info(info_key: String):
	if battery_info_path == "" && info_key == "capacity" && !(device_strategy is WindowsStrategy): 
		return device_strategy.get_battery_capacity()
		
	if !['status', 'capacity'].has(info_key): 
		print("Unkown battery info key: %s" % info_key)
		return ""
		
	var output = []
	var cmd = "%s/%s" % [battery_info_path, info_key]
	var exit_code = OS.execute("cat", [cmd], output)
	var result = output[0].strip_edges() if output.size() > 0 else ""
	return result
	
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
	var override_path = "%s%s" % [bin_path, HALLKEY_PATHS[hallkey_path]]
	var target_path = hallkey_path
	
	var args := ["--bind", override_path, target_path]
	var output := []
	var exit_code := OS.execute("mount", args, output, true)

	if exit_code != 0:
		push_error("Failed to bind mount hallkey: %s" % output)
	
func _on_music_stopped():
	# Only attempt unmount if the file exists
	if not FileAccess.file_exists(hallkey_path):
		return

	# Lazy unmount to handle busy sysfs files
	var exit_code := OS.execute("umount", ["-l", hallkey_path], [], true)

	if exit_code != 0:
		push_error("Failed to unmount hallkey override at %s" % hallkey_path)
