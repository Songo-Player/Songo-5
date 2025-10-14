extends DeviceOsStrategy
class_name GenericLinuxStrategy

var initial_brightness: int = 128

static func being_used() -> bool:
	return false
	#return OS.get_environment("CFW_NAME") == DeviceOS.CFW_MUOS
	
func _init():
	can_fade_screen = false
	
func get_music_dir_tip():
	return "Looks like you're using unknown CFW, good luck"
	
########################################
#       MUOS strategy exclusives       #
########################################
