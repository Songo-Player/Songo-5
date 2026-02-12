extends MarginContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	
func set_focus():
	%Button.grab_focus()
	
func setup_last_item():
	%ButtonSeparator.hide()
	
func setup(album_record, album_index):
	if %ButtonSeparator.visible == false: %ButtonSeparator.show()
	%Button.set_meta("item_index", album_index)
	%AlbumName.text = album_record.name
	%ArtistName.text = format_artists(album_record.artists)
	%FallbackCover.show()
	%AlbumCover.hide()
	
	if album_record.img_path != "":
		var loader = AsyncImageLoader.load_async(album_record.img_path)
		loader.image_loaded.connect(func(texture):
			%AlbumCover.texture = texture
			%AlbumCover.show()
		)
	
func format_artists(artists: Array) -> String:
	if artists.is_empty():
		return "Unknown Artist"
	
	var count := artists.size()
	
	if count == 1:
		return artists[0]
	elif count == 2:
		return "%s and %s" % [artists[0], artists[1]]
	elif count == 3:
		return "%s, %s, and %s" % [artists[0], artists[1], artists[2]]
	else:
		return "%s, %s, and %d others" % [artists[0], artists[1], count - 2]
