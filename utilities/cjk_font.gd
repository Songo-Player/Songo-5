class_name CjkFont
## Loads the full Noto Sans CJK font only once something needs it.
##
## The themes use a small Latin-only subset of Noto Sans. The full font (~16MB,
## kanji, kana and Hangul) is only read from disk and attached as that subset's
## fallback the first time text with CJK characters turns up: in the library,
## a playlist or music folder name, a song's lyrics, or the song now playing.
## Text already drawn with missing glyphs redraws when the fallback is added.
## See assets/fonts/source.

const LATIN_FONT = "res://assets/fonts/NotoSansCJKjp-Medium-Latin.otf"
const CJK_FONT = "res://assets/fonts/NotoSansCJKjp-Medium.otf"

# Scripts the full font covers that the Latin subset doesn't: Hangul Jamo,
# CJK radicals through unified ideographs (incl. kana, bopomofo, Hangul
# compatibility jamo), Hangul extensions and syllables, compatibility
# ideographs, vertical and compatibility forms, half/full-width forms, and
# the supplementary ideograph planes.
const CJK_PATTERN = "[\\x{1100}-\\x{11FF}\\x{2E80}-\\x{9FFF}\\x{A960}-\\x{A97F}\\x{AC00}-\\x{D7FF}\\x{F900}-\\x{FAFF}\\x{FE10}-\\x{FE1F}\\x{FE30}-\\x{FE4F}\\x{FF00}-\\x{FFEF}\\x{20000}-\\x{3FFFF}]"

# Records checked between frames while scanning the library
const SCAN_BATCH = 2000

static var _regex: RegEx
static var _requested := false

static func is_loaded() -> bool:
	return _requested

## True if `text` has a character only the full CJK font can draw
static func needs(text: String) -> bool:
	if text.is_empty(): return false
	if _regex == null:
		_regex = RegEx.new()
		_regex.compile(CJK_PATTERN)
	return _regex.search(text) != null

## Loads the font if `text` needs it
static func ensure_for(text: String) -> void:
	if not _requested && needs(text): load_font()

## Loads the font if any of `texts` needs it
static func ensure_for_all(texts: PackedStringArray) -> void:
	if not _requested && needs("\n".join(texts)): load_font()

## Looks through the library's tags, playlists and music folders, a batch per
## frame so a large library doesn't stall the UI, and loads the font on the
## first match.
static func scan_library(songo_data: SongoDataResource) -> void:
	if _requested: return
	var texts := PackedStringArray(songo_data.music_directory_paths)
	for playlist in songo_data.playlists:
		texts.append(playlist.name)
	for album in songo_data.albums:
		texts.append(album.name)
	for artist in songo_data.artists:
		texts.append(artist.name)
	ensure_for_all(texts)

	var records = songo_data.music_records
	var tree := Engine.get_main_loop() as SceneTree
	var i := 0
	while not _requested && i < records.size():
		texts = PackedStringArray()
		var end = min(i + SCAN_BATCH, records.size())
		for index in range(i, end):
			var record: TagLibMusicRecord = records.get_record(index)
			texts.append(record.title)
			texts.append(record.artist)
			texts.append(record.album)
			texts.append(record.album_artist)
			texts.append(record.full_path.get_file())
		ensure_for_all(texts)
		i = end
		if not _requested && i < records.size(): await tree.process_frame

## Loads the full font on a worker thread and attaches it as the Latin font's
## fallback. Safe to call more than once.
static func load_font() -> void:
	if _requested: return
	_requested = true
	print("Loading CJK font")
	ResourceLoader.load_threaded_request(CJK_FONT)
	var tree := Engine.get_main_loop() as SceneTree
	while ResourceLoader.load_threaded_get_status(CJK_FONT) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await tree.process_frame
	var cjk_font = ResourceLoader.load_threaded_get(CJK_FONT)
	# Falls back to a normal load if the threaded one failed
	if cjk_font == null: cjk_font = load(CJK_FONT)
	if cjk_font == null:
		push_error("Couldn't load CJK font at %s" % CJK_FONT)
		return

	# Shared by every theme that uses the Latin font, so this covers them all
	var latin_font: FontFile = load(LATIN_FONT)
	var fallbacks := latin_font.fallbacks
	fallbacks.append(cjk_font)
	latin_font.fallbacks = fallbacks
