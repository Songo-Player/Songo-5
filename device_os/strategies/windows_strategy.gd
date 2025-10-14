extends DeviceOsStrategy
class_name WindowsStrategy
# Windows Strategy

static func being_used():
	var os_name = OS.get_name()
	return os_name == "Windows"
	
var target_brightness = 10
func _init():
	can_fade_screen = false
	#swap_abxy()
	
func get_music_dir_tip():
	return "Looks like you're on Windows: Try looking in C:/Users/<you>/Music"

#FROM KNULLI TESTIN
func swap_abxy():
	var b_event := InputEventKey.new()
	b_event.keycode = KEY_B
	var enter_event := InputEventKey.new()
	enter_event.keycode = KEY_ENTER

	# --- Wipe the relevant actions ---
	if InputMap.has_action("ui_accept"):
		InputMap.erase_action("ui_accept")
		InputMap.add_action("ui_accept")

	if InputMap.has_action("back"):
		InputMap.erase_action("back")
		InputMap.add_action("back")

	# --- Rebind swapped mappings ---
	# ui_accept use B
	InputMap.action_add_event("ui_accept", b_event)

	# back now uses Enter
	InputMap.action_add_event("back", enter_event)
