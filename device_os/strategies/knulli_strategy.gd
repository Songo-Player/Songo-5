extends DeviceOsStrategy
class_name KnulliStrategy

var target_brightness: int = 255

static func being_used() -> bool:
	return OS.get_environment("CFW_NAME") == DeviceOS.CFW_KNULLI
	
func _init():
	can_fade_screen = true
	set_target_brightness()
	set_knulli_config()
	
func get_music_dir_tip():
	return "Looks like you're using Knulli: Try starting in /userdata/music/"

func set_backlight(level: int):
	var cmd := "brightness set %d" % level
	OS.execute("sh", ["-c", cmd])  # non-blocking
	
func get_battery_capacity():
	var cmd =  "batocera-info | grep Battery"
	var output = []
	var exit_code = OS.execute("sh", ["-c", cmd], output)
	var result = output[0].strip_edges() if output.size() > 0 else ""
	var battery_percent = RegEx.create_from_string("[^0-9]").sub(result, "", true)
	if  battery_percent == "": battery_percent = "N/A"
	return battery_percent

########################################
#       Knulli strategy exclusives     #
########################################

func set_target_brightness():
	#var cmd =  "source %s && DISPLAY_READ lcd0 getbl" % FUNC_SCRIPT
	var output = []
	var exit_code = OS.execute("sh", ["-c", "brightness get"], output)
	var result = output[0].strip_edges() if output.size() > 0 else ""
	if result != "":
		target_brightness = int(result)
		
func set_knulli_config():
	var reset_commands = []
	set_input_actions()
	
	OS.execute("sh", ["-c", "touch /var/run/battery-saver/songo.pause"])
	reset_commands.append("rm /var/run/battery-saver/songo.pause")
	reset_commands.append("batocera-brightness %d" % target_brightness)
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
