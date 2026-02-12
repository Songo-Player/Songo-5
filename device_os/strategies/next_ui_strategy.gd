extends DeviceOsStrategy
class_name NextUIStrategy

var target_brightness: int = 4
var bin_path = OS.get_environment("SONGO_BINARIES_DIR")

static func being_used() -> bool:
	var trim_ui_base = OS.get_environment("CFW_NAME") == DeviceOS.CFW_TRIM_UI
	if trim_ui_base == false: return false
	
	var output := []
	var exit_code := OS.execute("cat", ["/mnt/SDCARD/.system/version.txt"], output, true)

	if exit_code != 0 or output.is_empty():
		return false

	var text = output[0]
	return text.find("NextUI") != -1
	
func _init():
	dynamic_brightness = true
	can_fade_screen = true
	set_initial_brightness()
	set_config()
	
func get_music_dir_tip():
	return "Looks like you're using NextUI: Try starting in /mnt/SDCARD/"

func get_battery_capacity():
	var cmd =  "cat /tmp/percBat"
	var output = []
	var exit_code = OS.execute("sh", ["-c", cmd], output)
	var result = output[0].strip_edges() if output.size() > 0 else ""
	return result
	
########################################
#       TrimUI strategy exclusives     #
########################################

func set_backlight(level: int):
	var cmd = "%s/set-brightness %d" % [bin_path, level]
	OS.execute("sh", ["-c", cmd])

func set_initial_brightness():
	var cmd =  "%s/get_nextui_brightness" % bin_path
	var output = []
	var exit_code = OS.execute("sh", ["-c", cmd], output)
	var result = output[0].strip_edges() if output.size() > 0 else ""
	if result != "":
		target_brightness = max(int(result), 2)
		
func set_config():
	var reset_commands = []
	set_input_actions()
	
	#OS.execute("sh", ["-c", "touch /var/run/battery-saver/songo.pause"])
	#reset_commands.append("rm /var/run/battery-saver/songo.pause")
	#reset_commands.append("batocera-brightness %d" % target_brightness)
	create_reset_script(reset_commands)
	
func set_input_actions():
	var start_event = InputEventJoypadButton.new()
	start_event.button_index = JOY_BUTTON_START
	
	var east_event = InputEventJoypadButton.new()
	east_event.button_index = JOY_BUTTON_B
	var south_event = InputEventJoypadButton.new()
	south_event.button_index = JOY_BUTTON_A
	var north_event = InputEventJoypadButton.new()
	north_event.button_index = JOY_BUTTON_X
	var west_event = InputEventJoypadButton.new()
	west_event.button_index = JOY_BUTTON_Y
	

	InputMap.action_add_event("ui_accept", east_event)
	InputMap.action_add_event("back", south_event)
	InputMap.action_add_event("Y", north_event)
	InputMap.action_add_event("x", west_event)
	
	InputMap.action_add_event("start", start_event)
