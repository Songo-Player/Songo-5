extends MarginContainer
## A row on a collection page, written on a ruled notebook line (the line
## and the highlighter mark on focus come from the theme's ListButton
## styles). Songs are a line of handwriting with the running time jotted at
## the end; albums, artists and playlists get a tiny polaroid of their art,
## each tilted its own way. The host strips the containers this row doesn't
## use, so everything here is looked up with get_node_or_null.

const P = preload("../assets/palette.gd")
const Squiggle = preload("../assets/squiggle.gd")

func _ready() -> void:
	_fit_settings_row()
	for label in find_children("*", "Label", true, false):
		label.material = Squiggle.material(0.15)

func setup_music_record(record) -> void:
	$SongButtonContainer.show()
	if Controller.nav_label.has("Albums"):
		%SongName.text = record.get_title_with_track()
	else:
		%SongName.text = record.title
	%Duration.text = record.get_length_string()

func setup_album_record(record) -> void:
	$AlbumButtonContainer.show()
	%AlbumName.text = record.name
	%ArtistName.text = "by %s" % record.album_artist
	_pin_photo(%AlbumPhoto, "album", record)

func setup_artist_record(record) -> void:
	$ArtistButtonContainer.show()
	%RecordArtistName.text = record.name
	%ArtistSummary.text = get_song_summary(record.music_records)
	_pin_photo(%ArtistPhoto, "artist", record)

func setup_playlist_record(record) -> void:
	$PlaylistButtonContainer.show()
	%PlaylistName.text = record.name
	%PlaylistSummary.text = get_song_summary(record.music_records)
	_pin_photo(%PlaylistPhoto, "playlist", record)

# Each record's polaroid leans its own way, the same way every time.
func _pin_photo(photo: Control, kind: String, record) -> void:
	photo.tilt_degrees = float(hash(str(record.name)) % 9 - 4)
	photo.show_record(kind, record)

func _on_button_focus_entered() -> void:
	_tint(P.PENCIL_DARK)

func _on_button_focus_exited() -> void:
	_tint(P.PENCIL)

func _tint(color: Color) -> void:
	for path in ["%SongName", "%AlbumName", "%RecordArtistName", "%PlaylistName"]:
		var label := get_node_or_null(path) as Label
		if label: label.add_theme_color_override("font_color", color)

func get_song_summary(songs: Array) -> String:
	if songs.is_empty():
		return "nothing here yet"
	var total_seconds := 0.0
	for song in songs:
		total_seconds += song.raw_length
	var hours := int(total_seconds / 3600)
	var minutes := int((int(total_seconds) % 3600) / 60)
	var duration := "%dh %dm" % [hours, minutes] if hours > 0 else "%d min" % minutes
	return "%d song%s, %s" % [songs.size(), "" if songs.size() == 1 else "s", duration]

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
