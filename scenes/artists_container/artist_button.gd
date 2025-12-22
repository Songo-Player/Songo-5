extends MarginContainer

func setup_last_item():
	%ButtonSeparator.hide()
	
func set_focus():
	%Button.grab_focus()
	
func setup(artist_record, artist_index):
	if %ButtonSeparator.visible == false: %ButtonSeparator.show()
	%Button.set_meta("item_index", artist_index)
	%ArtistName.text = artist_record.name
	%ArtistSummary.text = get_song_summary(artist_record.music_records)
	%FallbackCover.show()
	%AlbumCover.hide()
	var loader = AsyncImageLoader.load_async(artist_record.img_path)
	loader.image_loaded.connect(func(texture):
		%AlbumCover.texture = texture
		%AlbumCover.show()
	)

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
