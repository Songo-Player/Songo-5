extends DeviceOsStrategy
class_name MuosCanadaGooseStrategy
# Muos Canada Goose Strategy
const FUNC_SCRIPT := "/opt/muos/script/var/func.sh"
const HOTKEY_SCRIPT := "/opt/muos/script/mux/hotkey.sh"

var target_brightness: int = 128

var config_values = {
	"idle_display": MuosConfigItem.new("settings/power/idle_display", "0", "unset"),
	"idle_sleep": MuosConfigItem.new("settings/power/idle_sleep", "0", "unset"),
	"lid_switch": MuosConfigItem.new("settings/advanced/lidswitch", "0", "unset")
}

static func being_used() -> bool:
	return OS.get_environment("CFW_NAME") == DeviceOS.CFW_MUOS
	
func _init():
	can_fade_screen = true
	set_initial_brightness()
	set_muos_config()
	set_input_actions()
	
func get_music_dir_tip():
	return "Looks like you're using MuOs: Try starting in /mnt/mmc/"
	
func get_battery_capacity():
	var location = get_var("device", "battery/capacity")
	var cmd =  "cat %s" % location
	var output = []
	var exit_code = OS.execute("sh", ["-c", cmd], output)
	var result = output[0].strip_edges() if output.size() > 0 else ""
	return result

func set_backlight(level: int):
	var cmd = "source %s && DISPLAY_WRITE lcd0 setbl %d" % [FUNC_SCRIPT, level]
	OS.execute("sh", ["-c", cmd])

########################################
#       MUOS strategy exclusives       #
########################################


func set_initial_brightness():
	var cmd =  "source %s && DISPLAY_READ lcd0 getbl" % FUNC_SCRIPT
	var output = []
	var exit_code = OS.execute("sh", ["-c", cmd], output)
	var result = output[0].strip_edges() if output.size() > 0 else ""
	if result != "":
		target_brightness = int(result)

func get_var(path_pt_1, path_pt_2):
	var cmd =  "source %s && GET_VAR %s %s" % [FUNC_SCRIPT, path_pt_1, path_pt_2]
	var output = []
	var exit_code = OS.execute("sh", ["-c", cmd], output)
	var result = output[0].strip_edges() if output.size() > 0 else ""
	return result
	
func set_var(path_pt_1, path_pt_2, param):
	var cmd = set_var_cmd(path_pt_1, path_pt_2, param)
	var output = []
	var exit_code = OS.execute("sh", ["-c", cmd], output)
	return exit_code

func hotkey_reset():
	var cmd =  "source %s && HOTKEY restart" % FUNC_SCRIPT
	var output = []
	var exit_code = OS.execute("sh", ["-c", cmd], output)
	var result = output[0].strip_edges() if output.size() > 0 else ""
	return result

func set_var_cmd(path_pt_1, path_pt_2, param):
	return "source %s && SET_VAR %s %s %s" % [FUNC_SCRIPT, path_pt_1, path_pt_2, param]
	
func set_muos_config():
	var reset_commands = []
	for config_item: MuosConfigItem in config_values.values():
		var og_val =  get_var("config", config_item.path)
		if og_val != "" && og_val != config_item.forced_val:
			config_item.og_val = og_val
			set_var("config", config_item.path, config_item.forced_val)
			reset_commands.append(set_var_cmd("config", config_item.path, config_item.og_val))
	
	hotkey_reset()
	reset_commands.append("source %s && DISPLAY_WRITE lcd0 setbl %d" % [FUNC_SCRIPT, target_brightness])
	reset_commands.append("source %s && HOTKEY restart" % FUNC_SCRIPT)
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

class MuosConfigItem:
	var path: String
	var forced_val: String
	var og_val: String
	
	func _init(path_arg, forced_val_arg, og_val_arg):
		path = path_arg
		forced_val = forced_val_arg
		og_val = og_val_arg
