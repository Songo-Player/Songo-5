extends DeviceOsStrategy
class_name RocknixStrategy

const FUNC_SCRIPT := "/etc/profile.d/001-functions"

static func being_used() -> bool:
	return OS.get_environment("CFW_NAME") == DeviceOS.CFW_ROCKNIX
	
func _init():
	set_input_actions()
	set_rocknix_config()
	
func get_music_dir_tip():
	return "You're using Rocknix: Try starting in /storage/roms/music"
		
func get_battery_capacity():
	var cmd =  "source %s && battery_percent" % FUNC_SCRIPT
	var output = []
	var exit_code = OS.execute("sh", ["-c", cmd], output)
	var result = output[0].strip_edges() if output.size() > 0 else ""
	return result

func set_rocknix_config():
	var reset_commands = []
	reset_commands.append("source %s && brightness set %d" % [FUNC_SCRIPT, 50])
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

	InputMap.action_add_event("ui_accept", south_event)
	InputMap.action_add_event("back", east_event)
	InputMap.action_add_event("x", north_event)
	InputMap.action_add_event("Y", west_event)
	
	InputMap.action_add_event("start", start_event)
