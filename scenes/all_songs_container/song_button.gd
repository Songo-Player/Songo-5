extends MarginContainer

func setup_last_item():
	%ButtonSeparator.hide()
	
func set_focus():
	%Button.grab_focus()
	
func setup(music_record, index):
	if %ButtonSeparator.visible == false: %ButtonSeparator.show()
	if Controller.nav_label.has("Albums"):
		%Button.text = music_record.title_with_track
	else:
		%Button.text = music_record.title
	%Duration.text = music_record.length
	%Button.set_meta("item_index", index)
