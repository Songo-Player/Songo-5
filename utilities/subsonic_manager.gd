extends Node

var node
var connected := false
var current_user: Dictionary = {}

signal connected_to_server
signal connection_failed(error: String)
signal song_download_ready(song_id: String, local_path: String)
signal song_download_failed(song_id: String, error: String)
signal cover_art_ready(cover_id: String, local_path: String)

var songo_settings = SongoSettings.get_instance()

var _cached_songs: Array[MusicRecord] = []
var _cached_albums: Array[AlbumRecord] = []
var _song_dicts: Dictionary = {}

func _ready():
	if not ClassDB.class_exists("SubsonicNode"):
		push_warning("SubsonicNode GDExtension not available. Subsonic disabled.")
		return
	node = ClassDB.instantiate("SubsonicNode")
	add_child(node)
	node.connect("download_completed", Callable(self, "_on_download_completed"))
	node.connect("download_failed", Callable(self, "_on_download_failed"))
	node.connect("cover_art_ready", Callable(self, "_on_cover_art_ready"))

	_load_config_from_file()
	if songo_settings.subsonic_url and songo_settings.subsonic_username:
		connect_to_server(songo_settings.subsonic_url, songo_settings.subsonic_username, songo_settings.subsonic_password)
	elif OS.get_environment("SUBSONIC_URL") and OS.get_environment("SUBSONIC_USERNAME"):
		connect_to_server(
			OS.get_environment("SUBSONIC_URL"),
			OS.get_environment("SUBSONIC_USERNAME"),
			OS.get_environment("SUBSONIC_PASSWORD")
		)

func _load_config_from_file():
	var config_path = "user://subsonic_config.json"
	if not FileAccess.file_exists(config_path):
		return
	var file = FileAccess.open(config_path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	var json = JSON.parse_string(text)
	if json == null or typeof(json) != TYPE_DICTIONARY:
		return
	if json.has("url") and json.has("username"):
		songo_settings.subsonic_url = str(json.url)
		songo_settings.subsonic_username = str(json.username)
		if json.has("password"):
			songo_settings.subsonic_password = str(json.password)
		songo_settings.save()
		print("Loaded Subsonic config from ", config_path)

func connect_to_server(url: String, username: String, password: String) -> bool:
	if not node:
		connection_failed.emit("GDExtension not loaded")
		return false

	node.set_server_url(url)
	node.set_credentials(username, password)
	node.set_cache_dir(OS.get_cache_dir() + "/subsonic")
	node.set_cache_max_mb(512)
	node.set_client_name("songo-subsonic")
	node.set_api_version("1.16.1")
	node.connect_to_server()

	var result = node.ping()
	connected = result.get("ok", false)

	if connected:
		var user_result = node.get_user(username)
		if user_result.get("ok", false):
			current_user = user_result.get("data", {})
		call_deferred("refresh_cache")
		connected_to_server.emit()
		return true
	else:
		var error = result.get("error", {})
		var error_msg = error.get("message", "Unknown error")
		connection_failed.emit(error_msg)
		return false

func disconnect_from_server():
	if node and connected:
		connected = false
		current_user = {}
		_cached_songs = []
		_cached_albums = []
		_song_dicts = {}
		connected_to_server.emit()

func refresh_cache():
	_cached_songs = []
	_cached_albums = []
	_song_dicts = {}
	_load_albums_into_cache()

func get_cached_songs() -> Array[MusicRecord]:
	return _cached_songs

func get_cached_albums() -> Array[AlbumRecord]:
	return _cached_albums

func is_subsonic_song(record: MusicRecord) -> bool:
	return record.full_path.begins_with("subsonic://")

func get_song_dict(song_id: String) -> Dictionary:
	return _song_dicts.get(song_id, {})

func _load_albums_into_cache():
	if not connected or not node:
		return
	var offset = 0
	var page_size = 50
	while true:
		var result = get_album_list("alphabeticalByName", page_size, offset)
		if not result.get("ok", false):
			print("Subsonic: get_album_list failed at offset ", offset, ": ", result)
			break
		var data = result.get("data", [])
		var page = data if data is Array else data.get("album", [])
		if page.is_empty():
			break
		for a in page:
			var ar = AlbumRecord.new()
			ar.name = a.get("name", "Unknown")
			ar.artists = [a.get("artist_name", a.get("artist", "Unknown Artist"))]
			ar.asset_id = a.get("coverArt", a.get("id", ""))
			_cached_albums.append(ar)
			_load_songs_for_album(ar, a.get("id", ""))
		if page.size() < page_size:
			break
		offset += page_size
	print("Subsonic: cached ", _cached_albums.size(), " albums, ", _cached_songs.size(), " songs")

func _load_songs_for_album(album_record: AlbumRecord, album_id: String):
	if not connected or not node:
		return
	var result = get_album(album_id)
	if not result.get("ok", false):
		print("Subsonic: failed to get album ", album_id, ": ", result)
		return
	var data = result.get("data", {})
	var entries = data.get("entries", [])
	for e in entries:
		var mr = _song_dict_to_music_record(e)
		_cached_songs.append(mr)
		album_record.music_records.append(mr)

func _song_dict_to_music_record(d: Dictionary) -> MusicRecord:
	var mr = MusicRecord.new()
	var sid = d.get("id", "")
	mr.full_path = "subsonic://%s" % sid
	mr.title = d.get("title", "Unknown")
	mr.raw_length = float(d.get("duration", 0))
	mr.album = d.get("album", "")
	mr.artist = d.get("artist", "")
	mr.track = d.get("track", 0)
	_song_dicts[sid] = d
	return mr

func get_artists() -> Dictionary:
	if not connected or not node:
		return {"ok": false, "error": "Not connected"}
	return node.get_artists()

func get_artist(artist_id: String) -> Dictionary:
	if not connected or not node:
		return {"ok": false, "error": "Not connected"}
	return node.get_artist(artist_id)

func get_album(album_id: String) -> Dictionary:
	if not connected or not node:
		return {"ok": false, "error": "Not connected"}
	return node.get_album(album_id)

func get_song(song_id: String) -> Dictionary:
	if not connected or not node:
		return {"ok": false, "error": "Not connected"}
	return node.get_song(song_id)

func get_album_list(list_type: String = "recent", size: int = 20, offset: int = 0) -> Dictionary:
	if not connected or not node:
		return {"ok": false, "error": "Not connected"}
	return node.get_album_list_2(list_type, size, offset)

func search(query: String, artist_count: int = 20, album_count: int = 20, song_count: int = 20) -> Dictionary:
	if not connected or not node:
		return {"ok": false, "error": "Not connected"}
	return node.search(query, artist_count, album_count, song_count)

func get_playlists() -> Dictionary:
	if not connected or not node:
		return {"ok": false, "error": "Not connected"}
	return node.get_playlists()

func get_playlist(playlist_id: String) -> Dictionary:
	if not connected or not node:
		return {"ok": false, "error": "Not connected"}
	return node.get_playlist(playlist_id)

func create_playlist(name: String, song_ids: PackedStringArray = []) -> Dictionary:
	if not connected or not node:
		return {"ok": false, "error": "Not connected"}
	return node.create_playlist(name, song_ids)

func delete_playlist(playlist_id: String) -> Dictionary:
	if not connected or not node:
		return {"ok": false, "error": "Not connected"}
	return node.delete_playlist(playlist_id)

func download_song(song_id: String):
	if not connected or not node:
		song_download_failed.emit(song_id, "Not connected")
		return
	node.download_song_async(song_id)

func get_stream_url(song_id: String, max_bitrate: int = -1) -> String:
	if not connected or not node:
		return ""
	return node.get_stream_url(song_id, max_bitrate)

func get_cover_art(cover_id: String, size: int = 300):
	if not connected or not node:
		return
	node.get_cover_art_async(cover_id, size)

func get_genres() -> Dictionary:
	if not connected or not node:
		return {"ok": false, "error": "Not connected"}
	return node.get_genres()

func get_music_folders() -> Dictionary:
	if not connected or not node:
		return {"ok": false, "error": "Not connected"}
	return node.get_music_folders()

func scrobble_song(song_id: String):
	if not connected or not node:
		return
	node.scrobble(song_id, true)

func star_song(song_id: String):
	if not connected or not node:
		return
	node.star(song_id)

func unstar_song(song_id: String):
	if not connected or not node:
		return
	node.unstar(song_id)

func _on_download_completed(song_id: String, local_path: String):
	song_download_ready.emit(song_id, local_path)

func _on_download_failed(song_id: String, error: Dictionary):
	var error_msg = error.get("message", "Unknown error")
	song_download_failed.emit(song_id, error_msg)

func _on_cover_art_ready(cover_id: String, local_path: String):
	cover_art_ready.emit(cover_id, local_path)
