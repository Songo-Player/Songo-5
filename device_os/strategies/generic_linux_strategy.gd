extends DeviceOsStrategy
class_name GenericLinuxStrategy

static func being_used() -> bool:
	if songo_data.preferred_device_strategy == "GenericLinuxStrategy": return true
	return false
	#return OS.get_environment("CFW_NAME") == DeviceOS.CFW_MUOS
	
func _init():
	can_fade_screen = false
	set_input_actions()
	
func get_music_dir_tip():
	return "Looks like you're using unknown CFW, good luck"

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
