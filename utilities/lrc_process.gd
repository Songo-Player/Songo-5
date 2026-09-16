extends Node

signal display_lyric(lyric_text)
# Parses the .lrc file adjacent to the currently playing song (if any) and
# flashes each lyric line via UiHelper at the correct playback time.

const SEEK_THRESHOLD_SECONDS := 1.5

var songo_settings = SongoSettings.get_instance()
var _lyrics: Array[Dictionary] = []
var _next_lyric_index: int = 0
var _last_pos: float = 0.0
var _active: bool = false
var logging: bool = false

func _ready() -> void:
	SongoPlayerV2.started_new_song.connect(_on_started_new_song)
	SongoPlayerV2.music_stopped.connect(_on_music_stopped)
	SongoPlayerV2.music_started.connect(_on_music_started)
	LrcScrape.lrc_saved.connect(_on_lrc_saved)

func _process(_delta: float) -> void:
	if not _active or not SongoPlayerV2.is_playing(): return

	var pos: float = SongoPlayerV2.get_playback_position()
	if pos < 0: return

	if absf(pos - _last_pos) > SEEK_THRESHOLD_SECONDS:
		_resync(pos)
	else:
		while _next_lyric_index < _lyrics.size() and pos >= _lyrics[_next_lyric_index].time:
			if songo_settings.render_lyrics && Controller.active_container is ThemeMainSongView:
				if display_lyric.get_connections().size() >= 1:
					display_lyric.emit(_lyrics[_next_lyric_index].text)
				else:
					UiHelper.flash_message(_lyrics[_next_lyric_index].text, 4.0, FlashMessage.TYPE.LYRIC)
			_next_lyric_index += 1

	_last_pos = pos

func _on_started_new_song(music_record: TagLibMusicRecord) -> void:
	_active = false
	_lyrics.clear()
	_next_lyric_index = 0
	_last_pos = 0.0

	if music_record == null or music_record.full_path.is_empty(): return
	var lrc_path := music_record.full_path.get_basename() + ".lrc"
	if not FileAccess.file_exists(lrc_path):
		if logging: print("LrcProcess: no lrc at %s yet, will pick it up if LrcScrape saves one" % lrc_path)
		return

	_lyrics = _parse_lrc(lrc_path)
	if _lyrics.is_empty(): return

	_last_pos = SongoPlayerV2.get_playback_position()
	_resync(_last_pos)
	_active = true

func _on_music_stopped() -> void:
	_active = false

func _on_music_started() -> void:
	if _lyrics.is_empty(): return
	_last_pos = SongoPlayerV2.get_playback_position()
	_resync(_last_pos)
	_active = true

func _on_lrc_saved(song_path: String, lrc_path: String) -> void:
	var current_song: TagLibMusicRecord = SongoPlayerV2.get_current_music_record()
	if current_song == null or current_song.full_path != song_path: return

	if logging: print("LrcProcess: freshly scraped lrc for currently playing song, loading it now")
	_lyrics = _parse_lrc(lrc_path)
	if _lyrics.is_empty(): return

	_last_pos = SongoPlayerV2.get_playback_position()
	_resync(_last_pos)
	_active = true

func _resync(pos: float) -> void:
	_next_lyric_index = 0
	while _next_lyric_index < _lyrics.size() and _lyrics[_next_lyric_index].time <= pos:
		_next_lyric_index += 1

func _parse_lrc(path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return result

	var timestamp_regex := RegEx.new()
	timestamp_regex.compile("\\[(\\d+):(\\d+(?:\\.\\d+)?)\\]")

	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty(): continue

		var matches := timestamp_regex.search_all(line)
		if matches.is_empty(): continue

		var text := timestamp_regex.sub(line, "", true).strip_edges()
		if text.is_empty(): continue

		for m in matches:
			var minutes := float(m.get_string(1))
			var seconds := float(m.get_string(2))
			result.append({"time": minutes * 60.0 + seconds, "text": text})

	file.close()
	result.sort_custom(func(a, b): return a.time < b.time)
	return result
