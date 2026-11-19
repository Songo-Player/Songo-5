extends MarginContainer
## A row on a collection page. Songs are typed index lines, the title dotted
## across to its running time. Albums, artists and playlists get their cover
## as a little print, developed in black and white; the row under focus
## shows it in color. The host strips the containers this row doesn't use,
## so everything here is looked up with get_node_or_null.

const P = preload("../assets/palette.gd")
const SILVER = preload("../assets/silver_print.tres")

# Labels that brighten while the row has focus.
const FOCUS_LABELS := ["%SongName", "%AlbumName", "%RecordArtistName", "%PlaylistName"]
const COVERS := ["%AlbumCover", "%ArtistImage", "%PlaylistImage"]

var _focused := false

func _ready() -> void:
	_fit_settings_row()
	for path in COVERS:
		var cover := get_node_or_null(path) as CanvasItem
		if cover: cover.material = SILVER
	ThemeManager.theme_settings_updated.connect(_apply_focus)

func setup_music_record(record) -> void:
	$SongButtonContainer.show()
	if Controller.nav_label.has("Albums"):
		%SongName.text = record.get_title_with_track()
	else:
		%SongName.text = record.title
	%Duration.text = record.get_length_string()
	%Leader.refresh()
	_apply_focus()

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
	_apply_focus()
	fallback.get_parent().get_parent().show()
	cover.hide()
	if not path: return
	var loader = AsyncImageLoader.load_async(path)
	loader.image_loaded.connect(func(texture):
		if not is_instance_valid(cover): return
		cover.texture = texture
		cover.show()
		fallback.get_parent().get_parent().hide()
	)

func _on_button_focus_entered() -> void:
	_focused = true
	_apply_focus()

func _on_button_focus_exited() -> void:
	_focused = false
	_apply_focus()

func _apply_focus() -> void:
	for path in FOCUS_LABELS:
		var label := get_node_or_null(path) as Label
		if label: label.add_theme_color_override("font_color", P.TEXT_BRIGHT if _focused else P.TEXT)
	var duration := get_node_or_null("%Duration") as Label
	if duration:
		if _focused: duration.add_theme_color_override("font_color", P.accent_ink())
		else: duration.remove_theme_color_override("font_color")
	# Under the spotlight, the print comes up in color.
	for path in COVERS:
		var cover := get_node_or_null(path) as CanvasItem
		if cover: cover.material = null if _focused else SILVER

func get_song_summary(songs: Array) -> String:
	if songs.is_empty():
		return "NO EXHIBITS"
	var total_seconds := 0.0
	for song in songs:
		total_seconds += song.raw_length
	var hours := int(total_seconds / 3600)
	var minutes := int((int(total_seconds) % 3600) / 60)
	var duration := "%dH %02dM" % [hours, minutes] if hours > 0 else "%d MIN" % minutes
	return "%d EXHIBIT%s  /  %s" % [songs.size(), "" if songs.size() == 1 else "S", duration]

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
