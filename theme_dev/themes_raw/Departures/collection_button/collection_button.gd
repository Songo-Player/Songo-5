extends MarginContainer
## A row on a collection page. Songs read like a timetable line, with the
## running time where the departure time would be. Albums, artists and
## playlists get their cover in a frame. The host strips the containers this
## row doesn't use, so everything here is looked up with get_node_or_null.

const P = preload("../assets/palette.gd")

# Labels that turn to the board color while the row has focus.
const FOCUS_LABELS := ["%SongName", "%AlbumName", "%RecordArtistName", "%PlaylistName"]

var _focused := false

func _ready() -> void:
	_fit_settings_row()
	ThemeManager.theme_settings_updated.connect(_apply_colors)

func _apply_colors() -> void:
	var duration := get_node_or_null("%Duration") as Label
	if duration: duration.add_theme_color_override("font_color", P.accent_ink())
	_tint_labels(P.accent_ink() if _focused else P.text())
	# Each record type's row has one cover frame (the others are stripped).
	for frame in find_children("Frame", "PanelContainer", true, false):
		var style := frame.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.bg_color = P.frame()
			style.border_color = P.rule()

func setup_music_record(record) -> void:
	$SongButtonContainer.show()
	if Controller.nav_label.has("Albums"):
		%SongName.text = record.get_title_with_track()
	else:
		%SongName.text = record.title
	%Duration.text = record.get_length_string()
	_apply_colors()

func setup_album_record(record) -> void:
	$AlbumButtonContainer.show()
	%AlbumName.text = record.name
	%ArtistName.text = str(record.album_artist).to_upper()
	_load_cover(%AlbumCover, %AlbumFallbackCover, Artwork.album_image_path(record.asset_id))

func setup_artist_record(record) -> void:
	$ArtistButtonContainer.show()
	%RecordArtistName.text = record.name
	%ArtistSummary.text = get_song_summary(record.music_records)
	_load_cover(%ArtistImage, %ArtistFallbackCover, Artwork.artist_image_path(record.asset_id))

func setup_playlist_record(record) -> void:
	$PlaylistButtonContainer.show()
	%PlaylistName.text = record.name
	%PlaylistSummary.text = get_song_summary(record.music_records)
	_load_cover(%PlaylistImage, %PlaylistFallbackCover, record.img_path if record.img_path else "")

func _load_cover(cover: TextureRect, fallback: TextureRect, path) -> void:
	_apply_colors()
	fallback.modulate = P.text_dim()
	fallback.show()
	cover.hide()
	if not path: return
	var loader = AsyncImageLoader.load_async(path)
	loader.image_loaded.connect(func(texture):
		if not is_instance_valid(cover): return
		cover.texture = texture
		cover.show()
		fallback.hide()
	)

func _on_button_focus_entered() -> void:
	_focused = true
	_tint_labels(P.accent_ink())

func _on_button_focus_exited() -> void:
	_focused = false
	_tint_labels(P.text())

func _tint_labels(color: Color) -> void:
	for path in FOCUS_LABELS:
		var label := get_node_or_null(path) as Label
		if label: label.add_theme_color_override("font_color", color)

func get_song_summary(songs: Array) -> String:
	if songs.is_empty():
		return "NO SERVICES"
	var total_seconds := 0.0
	for song in songs:
		total_seconds += song.raw_length
	var hours := int(total_seconds / 3600)
	var minutes := int((int(total_seconds) % 3600) / 60)
	var duration := "%dH %02dM" % [hours, minutes] if hours > 0 else "%dM" % minutes
	return "%d STOP%s  ·  %s" % [songs.size(), "" if songs.size() == 1 else "S", duration]

# A settings row keeps none of this scene's containers: the host draws it
# with its own button, sized by the button's text. At some global UI scales
# that comes out a fraction of a pixel taller than the spacing the list lays
# rows at, so neighbouring rows overlap and up/down focus skips every other
# one. Holding the row to the button's height rounded up to a whole pixel
# keeps them apart.
func _fit_settings_row() -> void:
	if get_child_count() > 0: return
	var host_button := get_parent().get_node_or_null("%Button") as Control
	if host_button == null: return
	var fit := func():
		custom_minimum_size.y = ceilf(host_button.get_combined_minimum_size().y)
	host_button.minimum_size_changed.connect(fit)
	fit.call()
