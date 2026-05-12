extends MarginContainer

var playlist
var songo_settings

func setup_last_item():
	%ButtonSeparator.hide()
	
#func set_focus():
#	%Button.grab_focus()
	
func setup(playlist_record: M3uCollection, playlist_index):
	playlist = playlist_record
	if %ButtonSeparator.visible == false: %ButtonSeparator.show()
	%Button.set_meta("playlist_index", playlist_index)
	%PlaylistName.text = playlist_record.name
	%PlaylistSummary.text = get_song_summary(playlist.music_records)
	%FallbackCover.show()
	%PlaylistCover.hide()
	
	songo_settings = SongoSettings.get_instance()
	if ["fff", "eee"].has(songo_settings.theme_color):
		%TheTail.modulate = Color("444")
		
	if playlist_record.img_path != "":
		var loader = AsyncImageLoader.load_async(playlist_record.img_path)
		loader.image_loaded.connect(func(texture):
			%PlaylistCover.texture = texture
			%PlaylistCover.show()
		)
	if !%Button.pressed.is_connected(_playlist_button_pressed):
		%Button.pressed.connect(_playlist_button_pressed)

func _playlist_button_pressed():
	Controller.playlist_songs_index(playlist)
	
func get_song_summary(songs: Array) -> String:
	if songs.is_empty():
		return "No songs"

	var total_songs := songs.size()
	var total_seconds := 0.0

	for song in songs:
		total_seconds += song.raw_length

	var hours := int(total_seconds / 3600)
	var minutes := int((int(total_seconds) % 3600) / 60)

	var hour_str := ""
	if hours > 0:
		hour_str = "%d hour%s" % [hours, "s" if hours != 1 else ""]

	var minute_str := "%d minute%s" % [minutes, "s" if minutes != 1 else ""]

	var time_str := hour_str
	if hour_str != "" and minute_str != "":
		time_str += " and " + minute_str
	elif hour_str == "":
		time_str = minute_str

	return "%d song%s totaling %s" % [total_songs, "s" if total_songs != 1 else "", time_str]


func _on_tree_entered() -> void:
	if playlist:
		%PlaylistSummary.text = get_song_summary(playlist.music_records)


func _on_button_mouse_entered() -> void:
	%Button.grab_focus()
