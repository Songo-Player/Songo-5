class_name SongoDataResource extends Resource

signal import_finished

const SAVE_PATH = "user://songo_data.tres"
const VERSION = "v0.4.0 RC2 Santa"
const DATA_VERSION = "30Tina"

@export var music_directory_path = "No Path"
@export var music_directory_paths = []
@export var music_records: Array[MusicRecord] = []
@export var data_version = ""
@export var artists: Array[ArtistRecord] = []
@export var albums: Array[AlbumRecord] = []
@export var recent_playlist_name = ""

var scraping: float = 0.0
var import_progress: float = 0.0
var import_step: int = 0
var _import_thread: Thread
var _stop_flag := false
var _albums := {}
var _artists := {}
var _song_paths := {}
var import_notes = []
var path_error = null
var existing_song_paths = []
var scale_components = []
var importing: bool = false
var playlists: Array[M3uCollection] = []
var import_start_time = 0

var artist_count: int:
	get: return artists.size()
	
var album_count: int:
	get: return albums.size()

# RYE TODO: This may not be used anymore
var music_records_alphabetical: 
	get: return get_music_records_alphabetical()
	
var recent_playlist:
	get: return get_recent_playlist()


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
			if _instance == null || _instance.data_version != DATA_VERSION:
				_instance = SongoDataResource.new()
				print("Busting saved data")
			else:
				#for playlist in _instance.playlists:
				#	playlist.load_music_records()
				#_instance.playlists = PlaylistRecord.load_playlists("user://playlists")
				_instance.playlists = M3uCollection.load_collection_type("playlists")
				M3uCollection.build_lookup(_instance.music_records)
				for playlist in _instance.playlists:
					playlist.music_records = playlist.get_music_records_from_lookup()
		else:
			_instance = SongoDataResource.new()
	return _instance
	 
func get_recent_playlist():
	var target = playlists.filter(func(playlist): return recent_playlist_name == playlist.name)
	if target.size() == 0: 
		if playlists.size() == 0: return null
		else: recent_playlist_name = playlists[0].name
		return playlists[0]
	else: return target[0]
		
func songs_in_album(album_name):
	var albums = albums.filter(func(album): return album.name == album_name)
	if albums.size() == 1: return albums[0].music_records
	else: return music_records
	
func get_album_cover(album_name):
	var albums = albums.filter(func(album): return album.name == album_name)
	if albums.size() == 1: return albums[0].cover
	else: return null
	
func unique_array(arr: Array) -> Array:
	var dict := {}
	for a in arr:
		dict[a] = 1
	return dict.keys()
	
func index_mp3s():
	importing = true
	existing_song_paths = music_records.map(func(r: MusicRecord): return r.full_path)
	_artists.clear()
	_albums.clear()
	_song_paths = {}
	start_import()

func clear_music_data():
	music_records.clear()
	albums.clear()
	artists.clear()
	save()

func get_mp3_paths(directory_path: String) -> Array:
	if directory_path == null or directory_path == "":
		return []

	var found_mp3s: Array = []
	var visited: Dictionary = {}

	var dir_test := DirAccess.open(directory_path)
	if dir_test == null:
		push_warning("Could not open root directory: %s" % directory_path)
		return found_mp3s

	_scan_dir_recursive(directory_path, found_mp3s, visited, ["mp3", "flac"])
	print("Found ", found_mp3s.size(), " Music files")
	return found_mp3s
	
func get_image_paths(directory_path: String) -> Array:
	if directory_path == null or directory_path == "":
		return []

	var found: Array = []
	var visited: Dictionary = {}

	var dir_test := DirAccess.open(directory_path)
	if dir_test == null:
		push_warning("Could not open root directory: %s" % directory_path)
		return found

	_scan_dir_recursive(directory_path, found, visited, ["png", "jpeg", "jpg", "webp"])
	print("Found ", found.size(), " Image files")
	return found

func _scan_dir_recursive(path: String, result: Array, visited: Dictionary, file_types: Array) -> void:
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
			_scan_dir_recursive(full_path, result, visited, file_types)
		elif is_file:
			var ext := file_name.get_extension().to_lower()
			if file_types.has(ext):
				if file_name.ends_with("GENERATED.png"): 
					pass
					#print("Ignoring generated image: %s" % file_name)
				elif existing_song_paths.has(full_path):
					pass
					#print("Ignoring already imported file: %s" % file_name)
				else:
					call_deferred("_update_import_progress", float(result.size()))
					result.append(full_path)
		else:
			# Neither dir nor file (broken link, device node, etc.)
			push_error("Skipping non-file entry:", full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	
func get_music_records_alphabetical():
	var sorted = music_records.duplicate()
	sorted.sort_custom(func(a: MusicRecord, b: MusicRecord): return a.title < b.title)
	return sorted
	
func get_albums_alphabetical():
	var sorted = albums.duplicate()
	sorted.sort_custom(func(a: AlbumRecord, b: AlbumRecord):
		var a_unknown := a.name == "Unknown Album"
		var b_unknown := b.name == "Unknown Album"
#
		if a_unknown and not b_unknown:
			return true
		elif b_unknown and not a_unknown:
			return false
		return a.name < b.name
	)
	return sorted
	
func get_artists_sorted_song_count():
	var sorted = artists.duplicate()
	sorted.sort_custom(func(a: ArtistRecord, b: ArtistRecord): return a.music_records.size() > b.music_records.size())
	return sorted
	
func save():
	print("Saving")
	data_version = DATA_VERSION
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
	var music_paths = []
	
	for path in music_directory_paths:
		music_paths.append_array(get_mp3_paths(path))
	print(music_paths.size())
	if music_paths.size() == 0:
		call_deferred("_add_flash_message", "No new music discovered, skipping import.")
		stop_import()
		call_deferred("_on_import_early_exit")
		return
	else:
		import_start_time = Time.get_unix_time_from_system()
		call_deferred("_add_flash_message", "Found %d music files, beginning import." % music_paths.size())
		
	call_deferred("_import_step_set", 1)
	import_progress = 0
	var count = music_paths.size()
	import_notes.append("Beginning import for %d music files" % count)

	for i in range(music_paths.size()):
		if _stop_flag:
			break
		var music_path = music_paths[i]
		_make_record(music_path)
		call_deferred("_on_record_imported", i/float(count))
	import_progress = 0
	call_deferred("_import_step_set", 2)

	var new_albums: Array[AlbumRecord]
	new_albums.assign(_albums.values())
	albums = AlbumRecord.merge_albums(albums, new_albums)
	build_album_images()

	var new_artists: Array[ArtistRecord]
	new_artists.assign(_artists.values())
	artists = ArtistRecord.merge_artists(artists, new_artists)
	call_deferred("_on_import_complete")
	return
	
func _make_record(file_path: String):
	var rec = MusicRecord.new()
	var meta_data = MetaDataHandler.get_basic_metadata(file_path)
	
	rec.full_path = file_path
	rec.album = meta_data.album
	rec.artist = meta_data.artist
	rec.title = meta_data.title
	rec.raw_length = meta_data.duration
	
	if not is_instance_valid(rec): return 
	if not _song_paths.has(rec.full_path):
		_song_paths[rec.full_path] = true
		music_records.append(rec)
	
	_create_or_update_album_from_music_record(rec)
	_create_or_update_artist_from_music_record(rec)
	
func _create_or_update_album_from_music_record(record: MusicRecord):
	if not _albums.has(record.album):
		var new_album = AlbumRecord.new()
		new_album.name = record.album
		_albums[record.album] = new_album

	if not _albums[record.album].music_records.has(record):
		_albums[record.album].music_records.append(record)
	
	for artist in record.artist.split(", "):
		if not _albums[record.album].artists.has(artist):
			_albums[record.album].artists.append(artist)

func _create_or_update_artist_from_music_record(record: MusicRecord):
	for artist_name in record.artist.split(", "):
		if not _artists.has(artist_name):
			var new_artist = ArtistRecord.new()
			new_artist.name = artist_name
			_artists[artist_name] = new_artist
			
		if not _artists[artist_name].music_records.has(record):
			_artists[artist_name].music_records.append(record)

func _add_flash_message(message: String):
	UiHelper.flash_message(message)
	
func _update_import_progress(progress: float):
	import_progress = progress
	
func _import_step_set(step: int):
	import_step = step
	
# --- callbacks executed on main thread ---
func _on_record_imported(progress: float):
	import_progress = progress
	
func build_artist_images():
	#print(artists)
	for i in range(artists.size()):	
		#var img_path = await WikiScrape.fetch_artist_image(artists[i].name)
		#if img_path == null || img_path == "":
		var img_path = await WikiScrape.fetch_dicebear_avatar(artists[i].name)
		artists[i].img_path = img_path
		scraping = float(i)/float(artists.size())
	call_deferred("save")
	scraping = 0.0
			
func build_album_images():
	var all_image_paths = []
	for path in music_directory_paths:
		all_image_paths.append_array(get_image_paths(path))
	
	var image_extractor = Mp3ImageExtractor.new()
	var allowed_exts = ["png", "jpg", "jpeg", "webp"]
	for i in range(albums.size()):
		call_deferred("_update_import_progress", i/float(albums.size()))
		#OS.delay_msec(100)
		if not _albums.keys().has(albums[i].name):
			#print("Skipping album image gen that wasnt updated: %s", albums[i].name )
			continue
		
		var album = albums[i]
		var album_song_paths = album.music_records.map(func(r: MusicRecord): return r.full_path)
		album.cover_path = ""
		var cover_image: Image = null
		var cover_path: String = ""
		var is_extracted := false

		# --- Method 1: Look for image in same folder as any album song
		for song_path in album_song_paths:
			var song_dir = song_path.get_base_dir().simplify_path().to_utf8_buffer()
			for image_path in all_image_paths:
				var ext = image_path.get_extension().to_lower()
				if ext in allowed_exts and image_path.get_base_dir().simplify_path().to_utf8_buffer() == song_dir:
					var img = Image.new()
					
					img = safe_load_image(image_path)
					if img != null:
						cover_image = img
						cover_path = image_path.get_basename() + "GENERATED.png"
						break
						
			if cover_image:
				break

		# --- Method 2: Look for image whose name matches album name
		if not cover_image:
			for image_path in all_image_paths:
				var ext = image_path.get_extension().to_lower()
				if ext in allowed_exts:
					var image_name = image_path.get_file().to_lower()
					var album_name = album.name.to_lower()
					if album_name in image_name:
						var img = Image.new()
						if img.load(image_path) == OK:
							cover_image = img
							cover_path = image_path.get_basename() + "GENERATED.png"
							break

		# --- Method 3: Extract embedded cover art and save to user://album_covers
		if not cover_image:
			for music_record in album.music_records:
				var img = image_extractor.get_cover_image(music_record.full_path)
				if img != null:
					cover_image = img
					is_extracted = true
					break

			if is_extracted:
				var base_dir = "user://album_covers"
				var album_dir = base_dir.path_join(sanitize_name(album.name))
				var dir = DirAccess.open("user://")
				if not dir.dir_exists(base_dir):
					dir.make_dir(base_dir)
				if not dir.dir_exists(album_dir):
					dir.make_dir(album_dir)
				cover_path = album_dir.path_join("cover.png")

		# --- Resize and Save (for all methods) ---
		if cover_image:
			var min_size = 180
			var w = cover_image.get_width()
			var h = cover_image.get_height()
			if w > 0 and h > 0:
				var scale = float(min_size) / min(w, h)
				var new_w = int(w * scale)
				var new_h = int(h * scale)
				cover_image.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)

			# Always save — if existing image, overwrite in place
			#cover_path = "user://album_covers/"+sanitize_name(album.name)+".png"
			var err = cover_image.save_png(cover_path)
			if err == OK:
				
				album.cover_path = cover_path#.to_utf8_buffer().get_string_from_utf8()
			else:
				pass
				#print("Failed to save cover for album %s" % album.name)
		else:
			pass
			#print("No cover found for album %s" % album.name)
		
func safe_load_image(path: String) -> Image:
	var img := Image.new()
	var err := img.load(path)
	if err == OK:
		return img

	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		push_error("FileAccess failed for: %s" % path)
		return null
	var data := f.get_buffer(f.get_length())
	f.close()

	# Try all supported formats by signature
	if data.size() >= 8 and data.slice(0, 8).get_string_from_ascii().find("PNG") != -1:
		err = img.load_png_from_buffer(data)
	elif data.size() >= 2 and data[0] == 0xFF and data[1] == 0xD8:
		err = img.load_jpg_from_buffer(data)
	elif data.size() >= 2 and data[0] == 0x42 and data[1] == 0x4D:
		err = img.load_bmp_from_buffer(data)
	else:
		# fallback guess
		err = img.load_jpg_from_buffer(data)
	if err != OK:
		push_error("Image decode failed for %s (err=%d)" % [path, err])
		return null

	return img
	
	
func _on_import_early_exit():
	import_step = 0
	importing = false
	import_finished.emit()
	
func _on_import_complete():
	print("ENDED")
	import_step = 0
	music_records = get_music_records_alphabetical()
	albums = get_albums_alphabetical()
	artists = get_artists_sorted_song_count()
	save()
	build_artist_images()
	var elapsed = Time.get_unix_time_from_system() - import_start_time
	UiHelper.flash_message("Import finished. Duration: %.2f seconds" % elapsed)
	importing = false
	M3uCollection.build_lookup(music_records)
	import_finished.emit()
	
func add_music_directory_path(path):
	if music_directory_paths.has(path): 
		path_error = "This directory is already added."
		return false
	
	for existing_path in music_directory_paths:
		var a = existing_path.rstrip("/")
		var b = path
		
		if b.begins_with(a + "/") or a.begins_with(b + "/"):
			path_error = "This Directory is a child of a directory you are already importing."
			return false
			
	music_directory_paths.append(path)
	return true
