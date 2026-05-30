extends MarginContainer

#@onready var virtualized_list = Controller.active_container.virtualized_list
var top_threshold = 100.0
var virtualized_list = null

func _ready() -> void:
	if "virtualized_list" in Controller.active_container:
		virtualized_list = Controller.active_container.virtualized_list

func _process(delta: float) -> void:
	if virtualized_list == null: return
	var visible_rect = virtualized_list.get_global_rect()
	var control_rect = get_global_rect()
	var control_top = control_rect.position.y
	var visible_top = visible_rect.position.y
	var is_in = control_top >= visible_top
	
	# Check if near the top AND inside
	var distance_from_top = control_top - visible_top
	var is_near_top = distance_from_top <= top_threshold
	
	if is_in and is_near_top:
		%TheTail.z_index = 1
	else:
		%TheTail.z_index = 0
	
func setup_last_item():
	%ButtonSeparator.hide()
	
func setup_music_record(record):
	$SongButtonContainer.visible = true
	if %ButtonSeparator.visible == false: %ButtonSeparator.show()
	
	if Controller.nav_label.has("Albums"):
		%SongName.text = record.title_with_track
	else:
		%SongName.text = record.title
		
	%Duration.text = record.length
	
func setup_album_record(record):
	$AlbumButtonContainer.visible = true
	if %ButtonSeparator.visible == false: %ButtonSeparator.show()

	%AlbumName.text = record.name
	%AlbumArtistName.text = format_artists(record.artists)
	%AlbumFallbackCover.show()
	%AlbumCover.hide()
	
	if record.img_path != "":
		var loader = AsyncImageLoader.load_async(record.img_path)
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
	
	if record.img_path:
		var loader = AsyncImageLoader.load_async(record.img_path)
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
