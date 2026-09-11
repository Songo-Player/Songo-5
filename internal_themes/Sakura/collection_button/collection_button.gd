extends MarginContainer

#@onready var virtualized_list = Controller.active_container.virtualized_list
var top_threshold = 100.0
var virtualized_list = null

func _ready() -> void:
	if "virtualized_list" in Controller.active_container:
		virtualized_list = Controller.active_container.virtualized_list

func _process(delta: float) -> void:
	pass
	
func setup_last_item():
	%ButtonSeparator.hide()
	
func setup_music_record(record):
	$SongButtonContainer.visible = true
	if %ButtonSeparator.visible == false: %ButtonSeparator.show()
	
	if Controller.nav_label.has("Albums"):
		%SongName.text = record.get_title_with_track()
	else:
		%SongName.text = record.title
		
	%Duration.text = record.get_length_string()
	
func setup_album_record(record):
	$AlbumButtonContainer.visible = true
	if %ButtonSeparator.visible == false: %ButtonSeparator.show()

	%AlbumName.text = record.name
	%AlbumArtistName.text = record.album_artist #format_artists(record.artists)
	%AlbumFallbackCover.show()
	%AlbumCover.hide()
	
	if Artwork.album_image_path(record.asset_id) != "":
		var loader = AsyncImageLoader.load_async(Artwork.album_image_path(record.asset_id))
		loader.image_loaded.connect(func(texture):
			%AlbumCover.texture = texture
			%AlbumCover.show()
		)
		
func setup_artist_record(record):
	$ArtistButtonContainer.visible = true
	if %ButtonSeparator.visible == false: %ButtonSeparator.show()

	%ArtistName.text = record.name
	%ArtistSummary.text = get_song_summary(record.music_records)
	%ArtistFallbackCover.show()
	%ArtistImage.hide()
	
	if Artwork.artist_image_path(record.asset_id):
		var loader = AsyncImageLoader.load_async(Artwork.artist_image_path(record.asset_id))
		loader.image_loaded.connect(func(texture):
			%ArtistImage.texture = texture
			%ArtistImage.show()
		)

func setup_playlist_record(record):
	$PlaylistButtonContainer.visible = true
	if %ButtonSeparator.visible == false: %ButtonSeparator.show()

	%PlaylistName.text = record.name
	%PlaylistSummary.text = get_song_summary(record.music_records)
	%PlaylistFallbackCover.show()
	%PlaylistCover.hide()
	
	if record.img_path != "":
		var loader = AsyncImageLoader.load_async(record.img_path)
		loader.image_loaded.connect(func(texture):
			%PlaylistCover.texture = texture
			%PlaylistCover.show()
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
