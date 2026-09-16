extends MarginContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	UiHelper.ui_event.connect(_on_toggle_info)

func set_for_track(track: TagLibMusicRecord):
	%FilePathLabel.set_carousel_text(track.full_path)
	%TrackTitleLabel.set_carousel_text(track.title)
	%AlbumNameLabel.set_carousel_text(track.album)
	%ArtistNameLabel.set_carousel_text(track.artist)
	%AlbumArtistLabel.set_carousel_text(track.album_artist)
	%LengthLabel.text = "%ds" % int(track.raw_length)
	
	
	%BitrateLabel.text = "%dkb/s" % track.bitrate
	%SampleRateLabel.text = "%shz" % track.sample_rate
	%FileSizeLabel.text = format_file_size(track.file_size)
	%FileTypeLabel.text = track.full_path.get_extension()
	
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
	#pass
	if visible:
		get_viewport().set_input_as_handled()
	
func handle_inputs(delta: float):
	pass
		
func _process(delta: float) -> void:
	if visible && Input.is_action_just_pressed("back"):
		hide()
	if visible && Input.is_action_just_pressed("select"):
		hide()
	
func _on_toggle_info(event):
	if event == UiHelper.EVENT.TOGGLE_INFO:
		if not visible:
			set_for_track(SongoPlayerV2.current_song)
			await get_tree().process_frame
			show()
		else:
			hide()
