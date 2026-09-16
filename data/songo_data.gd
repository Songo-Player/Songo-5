class_name SongoDataResource extends Resource

signal import_finished

const SAVE_PATH = "user://songo_data.tres"
const VERSION = "v1.0.0 RC3"
const DATA_VERSION = "46TaglibNative"

@export var music_directory_path = "No Path"
@export var music_directory_paths = []
@export var music_records: Array[TagLibMusicRecord] = []
@export var data_version = ""
@export var artists: Array[TagLibArtistRecord] = []
@export var albums: Array[TagLibAlbumRecord] = []
@export var target_playlist_index: int = -1

# music_records / albums / artists above are produced wholesale by
# GDTagLib.refresh_music_library each import -- GDTagLib parses the files and
# resolves the album / album-artist groupings. Nothing here derives them by hand.

var scraping: float = 0.0
var import_progress: float = 0.0
var import_step: int = 0
var images_rebuilt: int = 0
var _import_thread: Thread
var _rebuild_thread: Thread
var _stop_flag := false
var _rebuild_stop_flag := false
# Album names whose cover art needs (re)building this import pass.
var _changed_album_names := {}
var import_notes = []
var path_error = null
var scale_components = []
var importing: bool = false
var playlists: Array[M3uCollection] = []
var import_start_time = 0

var artist_count: int:
	get: return artists.size()
	
var album_count: int:
	get: return albums.size()
	
var target_playlist:
	get: return get_target_playlist()


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
				_instance.playlists = M3uCollection.load_collection_type("playlists")
				M3uCollection.build_lookup(_instance.music_records)
				for playlist in _instance.playlists:
					playlist.music_records = playlist.get_music_records_from_lookup()
		else:
			_instance = SongoDataResource.new()

	var bus := GDTagLib.get_singleton()
	if bus and not bus.library_update_planned.is_connected(_instance._on_library_update_planned):
		bus.library_update_planned.connect(_instance._on_library_update_planned)

	return _instance
	 
func get_target_playlist():
	if playlists.size() == 0: return null
	if target_playlist_index < 0 or target_playlist_index >= playlists.size():
		target_playlist_index = 0
	return playlists[target_playlist_index]

func remove_playlist(playlist: M3uCollection) -> void:
	var idx = playlists.find(playlist)
	if idx == -1: return
	playlists.erase(playlist)
	if playlists.size() == 0:
		target_playlist_index = -1
	elif idx == target_playlist_index:
		target_playlist_index = mini(target_playlist_index, playlists.size() - 1)
	elif idx < target_playlist_index:
		target_playlist_index -= 1
		
func songs_in_album(album_name):
	var albums = albums.filter(func(album): return album.name == album_name)
	if albums.size() == 1: return albums[0].music_records
	else: return music_records
	
func get_album_cover(album_name):
	var matches = albums.filter(func(album): return album.name == album_name)
	if matches.size() == 1: return Artwork.album_cover(matches[0])
	else: return null
	
func index_mp3s():
	importing = true
	images_rebuilt = 0
	start_import()

func rebuild_album_images():
	importing = true
	images_rebuilt = 0
	start_album_rebuild()

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

	_scan_dir_recursive(directory_path, found_mp3s, visited, ["mp3", "flac", "ogg", "m4a", "m4b", "aiff", "aif", "wav", "opus", "aac", "wma"])
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
				else:
					call_deferred("_update_import_progress", float(result.size()))
					result.append(full_path)
		else:
			# Neither dir nor file (broken link, device node, etc.)
			push_error("Skipping non-file entry:", full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	
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
func start_album_rebuild():
	if _rebuild_thread and _rebuild_thread.is_alive():
		return  # already running
	_rebuild_stop_flag = false
	_rebuild_thread = Thread.new()
	_rebuild_thread.start(Callable(self, "_thread_rebuild"))
	
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

func _thread_rebuild():
	import_progress = 0
	call_deferred("_import_step_set", 2)
	build_album_images(true)
	call_deferred("_on_album_image_rebuild_complete")
	
func _thread_import():
	import_step = 0
	import_progress = 0
	_changed_album_names = {}

	var all_paths: Array = []
	for path in music_directory_paths:
		all_paths.append_array(get_mp3_paths(path))

	if all_paths.size() == 0:
		stop_import()
		call_deferred("_on_import_early_exit")
		return

	import_start_time = Time.get_unix_time_from_system()

	# Parse-free diff: what's actually new / changed / gone since last time.
	# This also emits GDTagLib.library_update_planned -> _on_library_update_planned
	# turns the real counts into a flash message.
	var plan := GDTagLib.plan_music_library_update(music_records, PackedStringArray(all_paths), {})
	var to_read := {}
	for path in plan.added:
		to_read[path] = true
	for path in plan.changed:
		to_read[path] = true

	# Nothing added, changed or removed -> the library already matches disk.
	if to_read.is_empty() and plan.removed.is_empty():
		call_deferred("_on_import_early_exit")
		return

	for path in plan.removed:
		import_notes.append("Dropped missing file: %s" % path)

	call_deferred("_import_step_set", 1)
	import_progress = 0
	var count := all_paths.size()
	import_notes.append("Beginning import: %d new, %d changed, %d removed" % [plan.added.size(), plan.changed.size(), plan.removed.size()])

	# Slow, progress-reported pass: (re)parse only the files the plan flagged,
	# reuse the rest. GDTagLib groups them into albums / artists after.
	var prev_by_path := {}
	for r: TagLibMusicRecord in music_records:
		prev_by_path[r.full_path] = r

	var current: Array[TagLibMusicRecord] = []
	for i in range(all_paths.size()):
		if _stop_flag:
			break
		var p: String = all_paths[i]
		if to_read.has(p):
			var built := GDTagLib.build_music_record(p)
			current.append(built)
			_changed_album_names[built.album] = true
		else:
			current.append(prev_by_path[p])
		call_deferred("_on_record_imported", i / float(count))

	if _stop_flag:
		call_deferred("_on_import_early_exit")
		return

	import_progress = 0
	call_deferred("_import_step_set", 2)

	# Fast native pass: album + album-artist resolution over the whole library.
	var lib := GDTagLib.refresh_music_library(current, PackedStringArray(all_paths), {"follow_retags": false})
	music_records = []
	music_records.assign(lib.music_records)
	albums = []
	albums.assign(lib.albums)
	artists = []
	artists.assign(lib.artists)
	for artist in artists:
		Artwork.ensure_dicebear(artist.asset_id, "artist")

	build_album_images()
	call_deferred("_on_import_complete")


# GDTagLib.library_update_planned -- fired (deferred, main thread) from
# plan_music_library_update with the real work counts for this import.
func _on_library_update_planned(added: int, changed: int, removed: int) -> void:
	if added == 0 and changed == 0 and removed == 0:
		return
	var parts: Array[String] = []
	if added > 0: parts.append("%d new" % added)
	if changed > 0: parts.append("%d updated" % changed)
	if removed > 0: parts.append("%d removed" % removed)
	UiHelper.flash_message("Updating library: %s" % ", ".join(parts))


func _update_import_progress(progress: float):
	import_progress = progress
	
func _import_step_set(step: int):
	import_step = step
	
# --- callbacks executed on main thread ---
func _on_record_imported(progress: float):
	import_progress = progress
	
func _increment_images_rebuilt():
	images_rebuilt += 1
			
func build_album_images(rebuild: bool = false):
	var all_image_paths = []
	for path in music_directory_paths:
		all_image_paths.append_array(get_image_paths(path))
		
	var dir := DirAccess.open("user://")
	if not dir.dir_exists("album_images"):
		dir.make_dir("album_images")
	
	var allowed_exts = ["png", "jpg", "jpeg", "webp"]
	for i in range(albums.size()):
		call_deferred("_update_import_progress", i/float(albums.size()))
		#OS.delay_msec(100)
		if rebuild == false:
			if not _changed_album_names.has(albums[i].name):
				#print("Skipping album image gen that wasnt updated: %s", albums[i].name )
				continue
		
		var album = albums[i]
		var album_song_paths = album.music_records.map(func(r: TagLibMusicRecord): return r.full_path)
		var cover_image: Image = null
		var cover_path := "user://album_images/%s.webp" % album.asset_id

		if Artwork.album_image_path(album.asset_id) != "":
			continue
			
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
							#cover_path = image_path.get_basename() + "GENERATED.png"
							break

		# --- Method 3: Extract embedded cover art
		# get_cover() returns a decoded Image directly -- no Texture2D creation
		# and no GPU read-back, which matters on this worker thread.
		if not cover_image:
			for music_record in album.music_records:
				var img := GDTagLib.get_cover(music_record.full_path)
				if img != null:
					cover_image = img
					break


		# --- Normalise and save (for all methods) ---
		if cover_image:
			var min_size := 500
			var w := cover_image.get_width()
			var h := cover_image.get_height()

			# Only pay for a resample when the source is actually oversized.
			# INTERPOLATE_CUBIC is visually ~identical to LANCZOS at this size
			# and several times cheaper on ARM.
			var smallest := mini(w, h)
			if w > 0 and h > 0 and smallest > min_size:
				var scale := float(min_size) / float(smallest)
				cover_image.resize(int(w * scale), int(h * scale), Image.INTERPOLATE_CUBIC)

			# Lossy WebP: much faster to encode than PNG, smaller on disk.
			cover_image.save_webp(cover_path, true, 0.9)
		else:
			Artwork.ensure_dicebear(album.asset_id, "album")
		call_deferred("_increment_images_rebuilt")

		
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
	
func _on_album_image_rebuild_complete():
	import_step = 0
	save()
	UiHelper.flash_message("Album images rebuilt (%d images added)" % images_rebuilt)
	importing = false
	import_finished.emit()
	
func _on_import_complete():
	import_step = 0
	save()
	
	var elapsed = Time.get_unix_time_from_system() - import_start_time
	UiHelper.flash_message("Import finished. Duration: %.2f seconds" % elapsed)
	importing = false
	# music_records are rebuilt as fresh instances each import, so re-point the
	# playlists at them (identity matters for collection overlap checks).
	M3uCollection.build_lookup(music_records)
	for playlist in playlists:
		playlist.music_records = playlist.get_music_records_from_lookup()
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
