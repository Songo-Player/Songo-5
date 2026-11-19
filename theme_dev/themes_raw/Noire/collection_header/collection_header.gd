extends MarginContainer
## The title card beside a collection (the theme uses the side-by-side list
## layout). Under the NOIRE masthead: for a single album, artist or playlist,
## its photo and name (long names scroll past); for the lists, a line about
## them and their size, counted up when the page opens.

const P = preload("../assets/palette.gd")
const SILVER = preload("../assets/silver_print.tres")

const TYPE_ICONS := {
	"ALBUM": preload("res://assets/record.svg"),
	"ARTIST": preload("res://assets/user.svg"),
	"PLAYLIST": preload("res://assets/layergroup.svg"),
	"SETTING": preload("res://assets/gear.svg"),
}
const DEFAULT_ICON := preload("res://assets/music.svg")

# What each list's entries are called, and a line for the lists themselves.
const NOUNS := {
	"ALBUMS": "RECORD", "ARTISTS": "SUSPECT", "PLAYLISTS": "LIST",
	"SETTINGS": "SETTING", "PLUGIN": "ENTRY",
}
const LIST_LINES := {
	"ALL_SONGS": "THE WHOLE CITY",
	"ALBUMS": "EVERY RECORD ON FILE",
	"ARTISTS": "THE USUAL SUSPECTS",
	"PLAYLISTS": "NAMES. DATES. LISTS.",
	"SETTINGS": "THE FINE PRINT",
}

# The print takes whatever height the card has spare, up to PRINT_MAX (the
# photo's side, in pixels), so the card never outgrows the screen. Below
# PRINT_MIN it's left out rather than shrunk to a postage stamp.
const PRINT_MAX := 148.0
const PRINT_MIN := 40.0
const PRINT_BORDER := 5.0  # the white border, from the print's style
const NAME_GAP := 6.0

var _count_tween: Tween
var _has_print := false

func _ready() -> void:
	%CustomImage.material = SILVER
	%Stage.resized.connect(_layout_stage)
	_apply_settings()
	ThemeManager.theme_settings_updated.connect(_apply_settings)

func _apply_settings() -> void:
	%KindLabel.add_theme_color_override("font_color", P.accent_ink())

func setup(sort_key) -> void:
	var kind: String = str(CollectionHelper.collection_type)
	var collection = CollectionHelper.current_collection
	# Names too long for the card scroll past, marquee style.
	%NameLabel.set_carousel_text(str(CollectionHelper.collection_name).to_upper())
	%KindLabel.text = "FILE: " + kind.trim_suffix("_SONGS").replace("_", " ")

	%DefaultIcon.texture = DEFAULT_ICON
	for key in TYPE_ICONS:
		if key in kind:
			%DefaultIcon.texture = TYPE_ICONS[key]
			break
	# Only a single album, artist or playlist has a photo on file; the lists
	# of them (and All Songs) go without.
	var single := kind.ends_with("_SONGS") and kind != "ALL_SONGS"
	_has_print = single
	%Print.visible = single
	# The stage soaks up the spare height when there's a print to fill it;
	# otherwise the spacer does, keeping the lines together at the top.
	%Stage.size_flags_vertical = Control.SIZE_EXPAND_FILL if single else Control.SIZE_FILL
	%Spacer.visible = not single
	# Only the name is reserved: the print fits itself into what's left over.
	%Stage.custom_minimum_size.y = %NameLabel.get_combined_minimum_size().y
	_layout_stage.call_deferred()
	# A single album, artist or playlist lets its photo and name speak; the
	# detail and stats lines are only for the lists.
	%DetailLabel.visible = not single
	%StatsLabel.visible = not single
	var image_texture = CollectionHelper.collection_image_texture
	%CustomImage.visible = image_texture != null and image_texture is Texture2D
	%Dark.visible = not %CustomImage.visible
	if %CustomImage.visible: %CustomImage.texture = image_texture

	%DetailLabel.text = _detail_line(kind, collection)
	var total := int(CollectionHelper.collection_size)
	var noun: String = NOUNS.get(kind, "EXHIBIT")
	var running := ""
	if not NOUNS.has(kind):  # a list of songs: add up how long it runs
		running = "  /  " + _running_time(CollectionHelper._list_items)
	_run_count(total, noun, running)

	%SortLabel.text = ""
	if sort_key is String and SongoSort.TYPES.has(sort_key):
		var direction := "DESC" if "_desc" in sort_key else "ASC"
		%SortLabel.text = "%s  /  %s" % [str(SongoSort.TYPES[sort_key]).to_upper(), direction]

func _detail_line(kind: String, collection) -> String:
	if LIST_LINES.has(kind): return LIST_LINES[kind]
	match kind:
		"ALBUM_SONGS":
			var by := str(collection.album_artist) if collection and "album_artist" in collection else ""
			return "BY " + by.to_upper() if by != "" else "ARTIST UNKNOWN"
		"ARTIST_SONGS":
			var albums := {}
			if collection and "music_records" in collection:
				for record in collection.music_records:
					albums[str(record.album)] = true
			return "SEEN ON %d RECORD%s" % [albums.size(), "" if albums.size() == 1 else "S"]
		"PLAYLIST_SONGS":
			return "SOMEBODY KEPT A LIST"
	return "ON FILE"

func _running_time(songs) -> String:
	var seconds := 0.0
	if songs != null:
		for song in songs:
			seconds += maxf(float(song.raw_length), 0.0)
	var hours := int(seconds / 3600)
	var minutes := int((int(seconds) % 3600) / 60)
	return "%dH %02dM" % [hours, minutes] if hours > 0 else "%d MIN" % minutes

# The count ticks up like someone flipping through the file.
func _run_count(total: int, noun: String, suffix: String) -> void:
	if _count_tween: _count_tween.kill()
	var write := func(value: float):
		var n := int(value)
		%StatsLabel.text = "%d %s%s%s" % [n, noun, "" if n == 1 else "S", suffix]
	if total <= 1:
		write.call(float(total))
		return
	_count_tween = create_tween()
	_count_tween.tween_method(write, 0.0, float(total), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# The print is sized to fit the stage (the name needs its line under it) and
# centred at the top, with the name just beneath.
func _layout_stage() -> void:
	var stage: Control = %Stage
	var label: Label = %NameLabel
	var name_h := label.get_combined_minimum_size().y
	var y := 0.0
	var room := minf(stage.size.x - 8.0, stage.size.y - name_h - NAME_GAP - 4.0) - PRINT_BORDER * 2.0
	%Print.visible = _has_print and room >= PRINT_MIN
	if %Print.visible:
		var side := floorf(minf(room, PRINT_MAX))
		var outer := side + PRINT_BORDER * 2.0
		# The fallback icon's margins first, so the print's minimum size
		# doesn't hold it bigger than the side just picked.
		var inset := int(side * 0.3)
		for edge in ["left", "top", "right", "bottom"]:
			%IconMargin.add_theme_constant_override("margin_" + edge, inset)
		%Print.position = Vector2(floorf((stage.size.x - outer) / 2.0), 0.0)
		%Print.size = Vector2(outer, outer)
		y = outer + NAME_GAP
	label.position = Vector2(0.0, y)
	label.size = Vector2(stage.size.x, name_h)
