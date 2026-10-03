extends MarginContainer

# OverlayContainer runs the jump so it can fade the transition around it.
signal go_to_collection_requested(index_action: Callable, collection)

var info_panel_track: TagLibMusicRecord
var focus_return
# Frame the panel was opened on; the select press that opened it is still
# "just pressed" when our _process runs later that frame.
var _opened_frame := -1
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func set_for_track(track: TagLibMusicRecord):
	_opened_frame = Engine.get_process_frames()
	info_panel_track = track
	%GoToAlbumButton.grab_focus()
	%FilePathLabel.set_carousel_text(track.full_path)
	%TrackTitleLabel.set_carousel_text(track.title)
	%AlbumNameLabel.set_carousel_text(track.album)
	%ArtistNameLabel.set_carousel_text(track.artist)
	%AlbumArtistLabel.set_carousel_text(track.album_artist)
	%LengthLabel.text = "%ds" % int(track.raw_length)
	
	
	%BitrateLabel.text = "%dkb/s" % track.bitrate
	%SampleRateLabel.text = "%shz" % track.sample_rate
	%FileSizeLabel.text = format_file_size(track.file_size)
	%FileTypeLabel.text = track.file_type
	
	%Year.visible = track.year != 0
	%YearLabel.text = "%d" % track.year
	
	%DiscNum.visible = track.disc != 0
	%DiscNumLabel.text = "%d" % track.disc
	
	%TrackNum.visible = track.track != 0
	%TrackNumLabel.text = "%d" % track.track
	
	%Genre.visible = track.genre != ""
	%GenreLabel.text = track.genre
	
	%MbAlbumId.visible = track.musicbrainz_album_id != ""
	%AlbumIdLiteralLabel.visible = track.musicbrainz_album_id != ""
	%MbAlbumIdLabel.text = track.musicbrainz_album_id
	
	%HasLyrics.visible = FileAccess.file_exists(LrcScrape.get_lrc_path(track.full_path))
	%ListenCountLabel.text = "%d" % track.times_listened

func format_file_size(bytes: int) -> String:
	if bytes < 1024:
		return "%d B" % bytes

	var units := ["KB", "MB", "GB", "TB", "PB"]
	var size := float(bytes)
	var unit_index := -1

	while size >= 1024.0 and unit_index < units.size() - 1:
		size /= 1024.0
		unit_index += 1

	# Show 1 decimal place, but drop it if it's a whole number (e.g. "2 MB" not "2.0 MB")
	if size == floor(size):
		return "%d %s" % [int(size), units[unit_index]]
	else:
		return "%.1f %s" % [size, units[unit_index]]
		
func _input(event):
	pass
	#if visible:
	#	get_viewport().set_input_as_handled()
	
func handle_inputs(delta: float):
	pass
		
func _process(_delta: float) -> void:
	if not visible: return
	if Engine.get_process_frames() == _opened_frame: return
	if Input.is_action_just_pressed("back") || Input.is_action_just_pressed("select"):
		UiHelper.emit_signal("ui_event", UiHelper.EVENT.TOGGLE_INFO)
		#UiHelper.hide_info_panel()

func _on_go_to_album_button_pressed() -> void:
	var songo_data = SongoDataResource.get_instance()
	_go_to_collection(songo_data.albums, info_panel_track.album, Controller.albums_index, "album")


func _on_go_to_album_artist_button_pressed() -> void:
	var songo_data = SongoDataResource.get_instance()
	_go_to_collection(songo_data.artists, info_panel_track.album_artist, Controller.artists_index, "artist")


func _go_to_collection(collections: Array, preferred_name: String, index_action: Callable, kind: String) -> void:
	if info_panel_track == null: return
	var found = _find_collection_for_track(collections, info_panel_track, preferred_name)
	if found == null:
		UiHelper.flash_message("Couldn't find this track's %s, try reimporting." % kind)
		return
	go_to_collection_requested.emit(index_action, found)


# Albums/artists are grouped by more than name (e.g. album artist), so match on
# the file path and only use the name to pick between multiple hits.
# Returns null if no collection holds the track.
func _find_collection_for_track(collections: Array, track: TagLibMusicRecord, preferred_name: String):
	var fallback = null
	for collection in collections:
		for record in collection.music_records:
			if record.full_path == track.full_path:
				if collection.name == preferred_name: return collection
				if fallback == null: fallback = collection
				break
	return fallback
