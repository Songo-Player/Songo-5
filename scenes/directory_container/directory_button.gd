extends MarginContainer

func setup_last_item():
	%ButtonSeparator.hide()
	
func setup(directory_path, index):
	if %ButtonSeparator.visible == false: %ButtonSeparator.show()
	%Button.text = "/"+directory_path
	%Button.set_meta("dir_path", directory_path+"/")
	
	print(directory_path)
