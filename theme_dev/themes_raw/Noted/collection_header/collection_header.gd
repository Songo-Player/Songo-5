extends MarginContainer
## The side column of a collection page: a sticky note with the collection's
## art as a paperclipped polaroid, its name in big handwriting, what kind of
## list it is, how many things are in it, and how it's sorted.

const P = preload("../assets/palette.gd")
const Squiggle = preload("../assets/squiggle.gd")

# Each kind of list gets its own sticky note color, matching its menu tab.
const KIND_NOTES := {"ALBUM": 1, "ARTIST": 2, "PLAYLIST": 3, "SETTING": 4}

func _ready() -> void:
	%NameLabel.material = Squiggle.material(0.12)
	for label in [%KindLabel, %CountLabel, %SortLabel]:
		label.material = Squiggle.material(0.2)

func setup(sort_key) -> void:
	var kind: String = CollectionHelper.collection_type
	%NameLabel.text = str(CollectionHelper.collection_name)
	var count := int(CollectionHelper.collection_size)
	%CountLabel.text = "%d %s" % [count, _count_noun(kind, count)]
	%KindLabel.text = kind.replace("_", " ").to_lower()

	# All Songs is yellow; anything to do with albums, artists, playlists or
	# settings takes that tab's color (an album's song list included).
	var note_index := 0
	for key in ["ALBUM", "ARTIST", "PLAYLIST", "SETTING"]:
		if key in kind:
			note_index = KIND_NOTES[key]
			break
	var style := %Note.get_theme_stylebox("panel") as StyleBoxFlat
	style.bg_color = P.note(note_index)
	style.border_color = P.note_edge(note_index)

	var image = CollectionHelper.collection_image_texture
	%Polaroid.show_texture(image if image is Texture2D else null)

	%SortLabel.text = ""
	if sort_key is String and SongoSort.TYPES.has(sort_key):
		var direction := "desc" if "_desc" in sort_key else "asc"
		%SortLabel.text = "%s (%s)" % [str(SongoSort.TYPES[sort_key]).to_lower(), direction]
		UiHelper.flash_message("%s (%s)" % [SongoSort.TYPES[sort_key], direction.to_upper()])

# What the list is counting, e.g. "86 albums" on the Albums page but
# "21 songs" inside one album.
func _count_noun(kind: String, count: int) -> String:
	var noun := "songs"
	if "SONGS" in kind: noun = "songs"
	elif "ALBUMS" in kind: noun = "albums"
	elif "ARTISTS" in kind: noun = "artists"
	elif "PLAYLISTS" in kind: noun = "playlists"
	elif "SETTINGS" in kind: noun = "settings"
	return noun.trim_suffix("s") if count == 1 else noun
