extends DeviceOsStrategy
class_name WindowsStrategy
# Windows Strategy

static func being_used():
	if songo_data.preferred_device_strategy == "WindowsStrategy": return true
	var os_name = OS.get_name()
	return os_name == "Windows"
	
var target_brightness = 10
func _init():
	can_fade_screen = false
	
func translate_inputs(delta: float):
	pass
	
func get_music_dir_tip():
	return "You're on Windows: Try looking in C:/Users/<you>/Music"
