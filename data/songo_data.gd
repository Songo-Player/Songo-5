class_name SongoDataResource extends Resource

signal import_finished
const SAVE_PATH = "user://songo_data.tres"
const VERSION = "v0.1.1 Erica"
const THEME_COLORS = [
	"48486d", # Grayish blue
	"84233b", # Purpley
	"215a30", # Emerald Green
	"562b90", # Purpley Blue
]

@export var music_directory_path = "No Path"
@export var mp3_records: Array[Mp3Record] = []
@export var saved_version = ""
@export var theme_color = THEME_COLORS[3]
@export var artists = []
@export var albums: Array[AlbumRecord]

var import_progress: float = 0.0
var import_step: int = 0
var _import_thread: Thread
var _stop_flag := false
var _album_names := {}
var _song_paths := {}
var import_notes = []

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

func songs_in_album(album_name):
	var matches = mp3_records.filter(func(song): return song.album == album_name)
	return matches
	
func cover_for_song(file_path):
	var image_extractor = Mp3ImageExtractor.new()
	return image_extractor.get_cover_image(file_path)
	
func unique_array(arr: Array) -> Array:
	var dict := {}
	for a in arr:
		dict[a] = 1
	return dict.keys()
	
func index_mp3s():
	mp3_records.clear()
	albums.clear()
	
	_song_paths = {}
	_album_names = {}
	start_import()
	
func formatted_length(length_sec: float):
	var minutes: int = int(length_sec) / 60
	var seconds: int = int(length_sec) % 60
	return "%d:%02d" % [minutes, seconds]
	
func coalesce(value, default):
	return value if value != null and value != "" else default
	
func get_mp3_paths(directory_path: String) -> Array:
	if directory_path == null or directory_path == "":
		return []

	var found_mp3s: Array = []
	var visited: Dictionary = {}

	var dir_test := DirAccess.open(directory_path)
	if dir_test == null:
		push_warning("Could not open root directory: %s" % directory_path)
		return found_mp3s

	_scan_dir_recursive(directory_path, found_mp3s, visited)
	print("Found ", found_mp3s.size(), " MP3 files")
	return found_mp3s


func _scan_dir_recursive(path: String, result: Array, visited: Dictionary) -> void:
	if path in visited:
		return
	visited[path] = true

	var dir := DirAccess.open(path)
	if dir == null:
		print("Failed to open directory: ", path)
		return

	dir.list_dir_begin()  # skip . .. and hidden
	var file_name := dir.get_next()

	while file_name != "":
		var full_path := path.path_join(file_name)
		var is_dir := DirAccess.dir_exists_absolute(full_path)
		var is_file := FileAccess.file_exists(full_path)

		if is_dir:
			_scan_dir_recursive(full_path, result, visited)
		elif is_file:
			var ext := file_name.get_extension().to_lower()
			if ext == "mp3":
				call_deferred("_update_import_progress", result.size())
				result.append(full_path)
		else:
			# Neither dir nor file (broken link, device node, etc.)
			push_error("Skipping non-file entry:", full_path)

		file_name = dir.get_next()

	dir.list_dir_end()

	
func load_mp3_as_audio_stream(file_path: String) -> AudioStreamMP3:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		import_notes.append("Failure to load audio stream")
		print("Failed to open MP3 file: ", file_path)
		return null
	import_notes.append("Audio stream loaded")
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
		import_notes.append("Error saving imported data: %s" % error)
		return
		
func summarized_import_notes() -> String:
	if import_notes.is_empty():
		return ""
	
	var counts := {}
	for log in import_notes:
		counts[log] = counts.get(log, 0) + 1
	
	var summary_lines := []
	for log in counts.keys():
		var count = counts[log]
		if count > 1:
			summary_lines.append("%s (x%d)" % [log, count])
		else:
			summary_lines.append(log)
	
	return " | ".join(summary_lines)

func fallback_title(mp3_path):
	var file_name = mp3_path.get_file()
	if file_name.to_lower().ends_with(".mp3"):
		file_name = file_name.substr(0, file_name.length() - 4)
	file_name = file_name.replace("_", " ")
	return file_name + "*"
	
func sanitize_name(name: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^A-Za-z]")
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
	import_notes.clear()
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
	import_step = 0
	import_progress = 0

	var mp3_paths = get_mp3_paths(music_directory_path)
	call_deferred("_import_step_zero_done")
	import_progress = 0
	var count = mp3_paths.size()
	import_notes.append("Beginning import for %d mp3 files" % count)

	for i in range(mp3_paths.size()):
		if _stop_flag:
			break
		var mp3_path = mp3_paths[i]
		var record = _make_record(mp3_path)
		call_deferred("_on_record_imported", record, i/float(count))
	call_deferred("_on_import_complete")
	return
	
func _make_record(mp3_path: String) -> Mp3Record:
	#var audio_stream = load_mp3_as_audio_stream(mp3_path)
	var tagReader := MP3ID3TagV3.new()
	tagReader.file_path = mp3_path
	var rec = Mp3Record.new()
	rec.full_path = mp3_path
	rec.title = coalesce(tagReader.getTrackName(), fallback_title(mp3_path))
	rec.length = formatted_length(tagReader.getMp3LengthSeconds())
	#rec.length = formatted_length(audio_stream.get_length())
	rec.album = coalesce(tagReader.getAlbum(), "Unknown Album")
	rec.artist = coalesce(tagReader.getArtist(), "Unkown Artist")
	return rec
	
func _update_import_progress(file_count: int):
	import_progress = float(file_count)
	
func _import_step_zero_done():
	import_step = 1
	
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
		var cover_image = cover_for_song(record.full_path)
		var safe_name = sanitize_name(record.album)

		if cover_image != null:
			var min_size = 164
			var w = cover_image.get_width()
			var h = cover_image.get_height()
			var scale = float(min_size) / min(w, h)
			if w > 0 and h > 0:
				var new_w = int(w * scale)
				var new_h = int(h * scale)
				cover_image.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)
			
			cover_image.save_png("user://album_covers/" + safe_name + ".png")
			album.cover_path = "user://album_covers/" + safe_name + ".png"
		albums.append(album)
		
func _on_import_complete():
	import_step = 0
	import_notes.append("Import songs finished. (%d)" % mp3_records.size())
	mp3_records = get_mp3_records_alphabetical()
	import_notes.append("Imported songs alphabetized. (%d)" % mp3_records.size())
	save()
	import_notes.append("Import appears to have saved successfully")
	import_finished.emit()
