extends MarginContainer

var dir_path
func setup_last_item():
	%ButtonSeparator.hide()
	
func setup(directory_path, index):
	dir_path = directory_path+"/"
	if %ButtonSeparator.visible == false: %ButtonSeparator.show()
	%Button.text = "/"+directory_path
	#%Button.set_meta("dir_path", directory_path+"/")

func _on_button_mouse_entered() -> void:
	%Button.grab_focus()

func _on_button_pressed() -> void:
	var new_path = Controller.active_container.path_array.duplicate()
	new_path.append(dir_path)
	Controller.settings_directory_select(new_path)
