extends Node

# Fetches a synced .lrc file from lrclib.net and saves it next to the song
# file on disk, whenever SongoPlayerV2 starts a song that doesn't have one.

const LRCLIB_BASE_URL := "https://lrclib.net/api"

signal lrc_saved(song_path: String, lrc_path: String)

var songo_settings = SongoSettings.get_instance()
var _http_request: HTTPRequest
var _pending_music_record: TagLibMusicRecord
var _pending_lrc_path: String
var _pending_is_fallback: bool = false
var logging: bool = false

func _ready() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)
	SongoPlayerV2.started_new_song.connect(_on_started_new_song)

static func get_lrc_path(song_path: String) -> String:
	return song_path.get_basename() + ".lrc"

func _on_started_new_song(music_record: TagLibMusicRecord) -> void:
	if not songo_settings.scrape_lyrics:
		if logging: print("LrcScrape: scrape_lyrics setting disabled, skipping")
		return
	if music_record == null or music_record.full_path.is_empty():
		if logging: print("LrcScrape: started_new_song with no usable music_record, skipping")
		return
	if music_record.title.is_empty():
		if logging: print("LrcScrape: '%s' has no title tag, skipping lyric fetch" % music_record.full_path)
		return

	var lrc_path := get_lrc_path(music_record.full_path)
	if FileAccess.file_exists(lrc_path):
		if logging: print("LrcScrape: lrc already exists at %s, skipping fetch" % lrc_path)
		return

	if _http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		if logging: print("LrcScrape: cancelling in-flight request for previous song")
		_http_request.cancel_request()

	_pending_music_record = music_record
	_pending_lrc_path = lrc_path
	_pending_is_fallback = false
	_request_get()

func _request_get() -> void:
	var url := "%s/get?track_name=%s&artist_name=%s&album_name=%s&duration=%d" % [
		LRCLIB_BASE_URL,
		_pending_music_record.title.uri_encode(),
		_pending_music_record.artist.uri_encode(),
		_pending_music_record.album.uri_encode(),
		int(round(_pending_music_record.raw_length)),
	]
	if logging: print("LrcScrape: requesting %s" % url)
	var err := _http_request.request(url)
	if err != OK:
		push_warning("LrcScrape: request() failed to start, error %d for url %s" % [err, url])

func _request_search_fallback() -> void:
	_pending_is_fallback = true
	var url := "%s/search?track_name=%s&artist_name=%s" % [
		LRCLIB_BASE_URL,
		_pending_music_record.title.uri_encode(),
		_pending_music_record.artist.uri_encode(),
	]
	if logging: print("LrcScrape: exact match failed, falling back to search: %s" % url)
	var err := _http_request.request(url)
	if err != OK:
		push_warning("LrcScrape: fallback request() failed to start, error %d for url %s" % [err, url])

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if logging: print("LrcScrape: request completed, response_code=%d, is_fallback=%s" % [response_code, _pending_is_fallback])

	if response_code == 200:
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		var synced_lyrics := _extract_synced_lyrics(parsed)
		if not synced_lyrics.is_empty():
			if logging: print("LrcScrape: got synced lyrics (%d chars) for '%s'" % [synced_lyrics.length(), _pending_music_record.title])
			_save_lrc(_pending_music_record.full_path, _pending_lrc_path, synced_lyrics)
			return
		else:
			if logging: print("LrcScrape: response had no usable syncedLyrics field")

	if not _pending_is_fallback:
		_request_search_fallback()
	else:
		push_warning("LrcScrape: no synced lyrics found for '%s' by '%s'" % [_pending_music_record.title, _pending_music_record.artist])

func _extract_synced_lyrics(parsed) -> String:
	if parsed is Dictionary:
		return _synced_lyrics_of(parsed)
	if parsed is Array:
		for entry in parsed:
			if entry is Dictionary:
				var lyrics := _synced_lyrics_of(entry)
				if not lyrics.is_empty():
					return lyrics
	return ""

func _synced_lyrics_of(entry: Dictionary) -> String:
	var lyrics = entry.get("syncedLyrics", "")
	if lyrics == null or typeof(lyrics) != TYPE_STRING:
		return ""
	return lyrics

func _save_lrc(song_path: String, lrc_path: String, synced_lyrics: String) -> void:
	if synced_lyrics.is_empty():
		if logging: print("LrcScrape: refusing to save empty lyrics for %s" % song_path)
		return

	var file := FileAccess.open(lrc_path, FileAccess.WRITE)
	if file == null:
		push_warning("LrcScrape: failed to write lrc file at %s" % lrc_path)
		return
	file.store_string(synced_lyrics)
	file.close()
	if logging: print("LrcScrape: saved lrc to %s" % lrc_path)
	lrc_saved.emit(song_path, lrc_path)
