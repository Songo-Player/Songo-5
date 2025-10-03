class_name SongoDataResource extends Resource

signal import_finished
const SAVE_PATH = "user://songo_data.tres"
const VERSION = "v0.0.7 Monica"
const THEME_COLORS = [
	"48486d", # Grayish blue
	"84233b", # Purpley
	"215a30", # Emerald Green
	"562b90", # Purpley Blue
]

@export var music_directory_path = null
@export var mp3_records: Array[Mp3Record] = []
@export var saved_version = ""
@export var theme_color = THEME_COLORS[3]
@export var artists = []
@export var albums: Array[AlbumRecord]

var import_progress: float = 0.0
var _import_thread: Thread
var _stop_flag := false
var _album_names := {}
var _song_paths := {}

var artist_count: int:
	get: return artists.size()
	
var album_count: int:
	get: return albums.size()

var mp3_records_alphabetical: 
	get: return get_mp3_records_alphabetical()

static var _instance : SongoDataResource = null

func _init():
	if _instance != null and _instance != self:
		push_error("SongoData is a singleton! Use SongoData.get_instance() instead of creating new instances.")
		return
		
static func get_instance() -> SongoDataResource:
	ensure_dir("album_covers")
	
	if _instance == null:
		if ResourceLoader.exists(SAVE_PATH):
			_instance = ResourceLoader.load(SAVE_PATH)
			if _instance == null || _instance.saved_version != VERSION:
				_instance = SongoDataResource.new()
				print("Busting saved data")
		else:
			_instance = SongoDataResource.new()
	return _instance
	
func cache_artists():
	artists = unique_array(mp3_records.map(func(r: Mp3Record): return r.artist))

func cache_albums():
	var music_meta_obj = MusicMeta.new()
	albums.clear()
	var mp3_records_dup = mp3_records.duplicate()
	var album_names = unique_array(mp3_records_dup.map(func(r: Mp3Record): return r.album))
	for album_name in album_names:
		var album_record = AlbumRecord.new()
		album_record.name = album_name
		print("albumc thin")
		print(songs_in_album(album_name).size())
		for song in songs_in_album(album_name):
			var stream = load_mp3_as_audio_stream(song.full_path)
			var meta_data = music_meta_obj.get_mp3_metadata(stream)
			if meta_data.cover:
				album_record.cover = meta_data.cover
				break
		albums.append(album_record)
	
func songs_in_album(album_name):
	var matches = mp3_records.filter(func(song): return song.album == album_name)
	return matches
	
func cover_for_song(file_path):
	var song = load_mp3_as_audio_stream(file_path)
	var music_meta_obj = MusicMeta.new()
	return music_meta_obj.get_mp3_metadata(song).cover
	
func unique_array(arr: Array) -> Array:
	var dict := {}
	for a in arr:
		dict[a] = 1
	return dict.keys()
	
func index_mp3s():
	start_import()
	
func formatted_length(length_sec: float):
	var minutes: int = int(length_sec) / 60
	var seconds: int = int(length_sec) % 60
	return "%d:%02d" % [minutes, seconds]
	
func coalesce(value, default):
	return value if value != null and value != "" else default
	
func get_mp3_paths_OLD(directory_path):
	if directory_path == null: return []
	
	var dir = DirAccess.open(directory_path)
	var found_mp3s = []
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		dir.list_dir_begin()
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.get_extension().to_lower() == "mp3":
				var full_path = directory_path + "/" + file_name
				found_mp3s.append(full_path)
			file_name = dir.get_next()
			
		dir.list_dir_end()
		print("Found ", found_mp3s.size(), " MP3 files")
	else:
		print("Failed to open directory: ", directory_path)
		
	return found_mp3s
	
func get_mp3_paths(directory_path: String) -> Array:
	if directory_path == null:
		return []

	var found_mp3s := []
	_scan_dir_recursive(directory_path, found_mp3s)
	print("Found ", found_mp3s.size(), " MP3 files")
	return found_mp3s


func _scan_dir_recursive(path: String, result: Array) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		print("Failed to open directory: ", path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		# Skip current/parent directories
		if file_name != "." and file_name != "..":
			var full_path = path + "/" + file_name
			if dir.current_is_dir():
				# Recurse into subdirectory
				_scan_dir_recursive(full_path, result)
			elif file_name.get_extension().to_lower() == "mp3":
				result.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	
func load_mp3_as_audio_stream(file_path: String) -> AudioStreamMP3:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Failed to open MP3 file: ", file_path)
		return null
	
	var audio_stream = AudioStreamMP3.new()
	audio_stream.data = file.get_buffer(file.get_length())
	file.close()
	
	return audio_stream
	
func get_mp3_records_alphabetical():
	var sorted = mp3_records.duplicate()
	sorted.sort_custom(func(a: Mp3Record, b: Mp3Record): return a.title < b.title)
	return sorted
	
func save():
	saved_version = VERSION
	var error = ResourceSaver.save(self, SAVE_PATH)
	if error != OK:
		print("Error saving collection: ", error)
		return

func sanitize_name(name: String) -> String:
	var regex := RegEx.new()
	# Match anything NOT A–Z or a–z
	regex.compile("[^A-Za-z]")
	# Replace with empty string
	var result := regex.sub(name, "", true)
	
	if result.is_empty():
		result = "album"
	return result

static func ensure_dir(path: String) -> void:
	var dir := DirAccess.open("user://")
	if not dir.dir_exists(path):
		dir.make_dir_recursive(path)

# --- threaded import entrypoint ---
func start_import():
	if _import_thread and _import_thread.is_alive():
		return  # already running
	_stop_flag = false
	_import_thread = Thread.new()
	_import_thread.start(Callable(self, "_thread_import"))

func stop_import():
	_stop_flag = true
	if _import_thread and _import_thread.is_alive():
		_import_thread.wait_to_finish()

func _thread_import():
	var music_meta_obj = MusicMeta.new()
	mp3_records.clear()
	import_progress = 0

	var mp3_paths = get_mp3_paths(music_directory_path)
	var count = mp3_paths.size()

	for i in mp3_paths.size():
		if _stop_flag:
			break

		var mp3_path = mp3_paths[i]
		var record = _make_record(mp3_path, music_meta_obj)
		call_deferred("_on_record_imported", record, i/float(count))
	call_deferred("_on_import_complete")
	return


func _make_record(mp3_path: String, music_meta_obj: MusicMeta) -> Mp3Record:
	var audio_stream = load_mp3_as_audio_stream(mp3_path)
	var meta_data = music_meta_obj.get_mp3_metadata(audio_stream)

	var rec = Mp3Record.new()
	rec.full_path = mp3_path
	rec.title = meta_data.title
	rec.length = formatted_length(audio_stream.get_length())
	rec.album = coalesce(meta_data.album, "Unknown Album")
	rec.artist = meta_data.artist
	return rec

# --- callbacks executed on main thread ---
func _on_record_imported(record: Mp3Record, progress: float):
	if not _song_paths.has(record.full_path):
		_song_paths[record.full_path] = true
		mp3_records.append(record)
		
	if not _album_names.has(record.album):
		_album_names[record.album] = true
		_update_album(record)
		
	import_progress = progress

func _update_album(record):
	var record_album = albums.filter(func(album): return record.album == album.name)
	if record_album.size() == 0:
		var album = AlbumRecord.new()
		album.name = record.album
		album.artist = record.artist
		var cover_image = cover_for_song(record.full_path).get_image()
		var safe_name = sanitize_name(record.album)
		
		var min_size = 164
		var w = cover_image.get_width()
		var h = cover_image.get_height()
		if w > 0 and h > 0:
			var scale = float(min_size) / min(w, h)
			var new_w = int(w * scale)
			var new_h = int(h * scale)
			cover_image.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)
			
		cover_image.save_png("user://album_covers/" + safe_name + ".png")
		album.cover_path = "user://album_covers/" + safe_name + ".png"
		albums.append(album)
		
func _on_import_complete():
	mp3_records = get_mp3_records_alphabetical()
	cache_artists()
	save()
	import_finished.emit()
