extends MarginContainer

var index
var songo_settings

func setup_last_item():
	%ButtonSeparator.hide()
	
func set_focus():
	%Button.grab_focus()
	
func setup(music_record, index_arg):
	index = index_arg
	if %ButtonSeparator.visible == false: %ButtonSeparator.show()
	if Controller.nav_label.has("Albums"):
		%SongName.text = music_record.title_with_track
	else:
		%SongName.text = music_record.title
		
	%Duration.text = music_record.length
	%Button.set_meta("item_index", index)
	songo_settings = SongoSettings.get_instance()
	#if ["fff", "eee"].has(songo_settings.theme_color):
	#	%TheTail.modulate = Color("444")
	
	if !%Button.pressed.is_connected(_song_button_pressed):
		%Button.pressed.connect(_song_button_pressed)
	
func _song_button_pressed():
	var current_page = Controller.active_container
	if "music_records" in current_page:
		Controller.songs_panel(current_page.music_records, index)

func _on_button_mouse_entered() -> void:
	%Button.grab_focus()
