extends Node
class_name DeviceOsStrategy

var music_dir_tip: String: get = get_music_dir_tip
var can_fade_screen: bool

static func being_used() -> bool:
	print("Implement me in child");
	return false
	
#func _init():
	#create_reset_script()
	
func get_music_dir_tip():
	return ""
	
func create_reset_script(commands: Array):
	var reset_path = "user://reset_values.sh"
	var reset_script = "#!/bin/sh\n"
	
	for command in commands:
		reset_script += command + "\n"
		
	reset_script += "echo WEEEEEEWOO\n"
	var file = FileAccess.open(reset_path, FileAccess.WRITE)
	
	if file == null:
		print("Error opening file: ", FileAccess.get_open_error())
		return
		
	file.store_string(reset_script)
	file.close()
	
	# Make it executable
	OS.execute("chmod", ["+x", ProjectSettings.globalize_path(reset_path)])
