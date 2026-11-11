class_name SongoDataResource extends Resource

signal import_finished

const SAVE_PATH = "user://songo_data.res"
# Tracks, albums and artists (with play counts), in GDTagLib's flat binary
# format. Kept out of SAVE_PATH because it's far faster to load and save.
const LIBRARY_PATH = "user://songo_library.bin"
const VERSION = "v1.0.0 RC7"
const DATA_VERSION = "v1.0.0 RC7.1"

@export var music_directory_path = "No Path"
@export var music_directory_paths = []
@export var data_version = ""
@export var target_playlist_index: int = -1

# Produced wholesale by GDTagLib.refresh_music_library each import -- GDTagLib
# parses the files and resolves the album / album-artist groupings. Nothing
# here derives them by hand. Deliberately not @export: they're persisted to
# LIBRARY_PATH (see save_library), not into this Resource.
var music_records: Array[TagLibMusicRecord] = []
var artists: Array[TagLibArtistRecord] = []
var albums: Array[TagLibAlbumRecord] = []

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
# When true the scan step (import_step 0) runs without the import panel, which
# only appears once the scan finds changes. Used for the auto import on boot.
var import_quiet_scan: bool = false
var playlists: Array[M3uCollection] = []
var import_start_time = 0
# Play counts changed since the last save (see save_listens).
var listens_dirty: bool = false

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
		var boot_start_ms := Time.get_ticks_msec()
		print("BOOT: SongoDataResource load start at %d ms" % boot_start_ms)
		if ResourceLoader.exists(SAVE_PATH):
			_instance = ResourceLoader.load(SAVE_PATH)
			print("BOOT: SongoDataResource file read done at %d ms (%d ms)" % [Time.get_ticks_msec(), Time.get_ticks_msec() - boot_start_ms])
			if _instance == null || _instance.data_version != DATA_VERSION:
				_instance = SongoDataResource.new()
				print("Busting saved data")
			else:
				_instance._load_library()
				_instance.playlists = _instance._discover_playlists(_instance.scan_music_directories(["playlists"]).playlists)
				M3uCollection.build_lookup(_instance.music_records)
				for playlist in _instance.playlists:
					playlist.music_records = playlist.get_music_records_from_lookup()
		else:
			_instance = SongoDataResource.new()
		print("BOOT: SongoDataResource load end at %d ms (%d ms total, %d tracks, %d albums, %d artists, %d playlists)" % [
			Time.get_ticks_msec(), Time.get_ticks_msec() - boot_start_ms,
			_instance.music_records.size(), _instance.albums.size(), _instance.artists.size(), _instance.playlists.size()])

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
	
func index_mp3s(quiet_scan: bool = false):
	import_quiet_scan = quiet_scan
	importing = true
	images_rebuilt = 0
	start_import()

func rebuild_album_images():
	import_quiet_scan = false
	importing = true
	images_rebuilt = 0
	start_album_rebuild()

func clear_music_data():
	music_records.clear()
	albums.clear()
	artists.clear()
	save()

const AUDIO_EXTS := ["mp3", "flac", "ogg", "m4a", "m4b", "aiff", "aif", "wav", "opus", "aac", "wma"]
const IMAGE_EXTS := ["png", "jpeg", "jpg", "webp"]
const PLAYLIST_EXTS := ["m3u"]

# One native walk of every music directory, sorting files into the requested
# groups ("audio", "images", "playlists") by extension. progress (optional)
# gets the running file count. Groups in stamp_groups also come back with
# "<group>_mtimes" / "<group>_sizes", stat()ed during the walk.
func scan_music_directories(groups: Array, progress := Callable(), stamp_groups: Array = []) -> Dictionary:
	var exts := {"audio": AUDIO_EXTS, "images": IMAGE_EXTS, "playlists": PLAYLIST_EXTS}
	var request := {}
	for group in groups:
		request[group] = PackedStringArray(exts[group])
	var found := GDTagLib.scan_directories(PackedStringArray(music_directory_paths), request, progress,
		{"stamps": PackedStringArray(stamp_groups)})
	if found.has("images"):
		found.images = Array(found.images).filter(func(p: String): return not p.ends_with("GENERATED.png"))
	for group in groups:
		print("Found ", found[group].size(), " ", group, " files")
	return found

# Turns .m3u files under the configured music directories that aren't
# already tracked in `playlists` into collections -- covers both playlists
# this app created and ones dropped in by other music apps. Discovered
# playlists are left exactly where they are on disk.
func _discover_playlists(m3u_paths) -> Array[M3uCollection]:
	var discovered: Array[M3uCollection] = []
	var known := {}
	for existing_playlist in playlists:
		known[existing_playlist.m3u_path] = true

	for m3u_path in m3u_paths:
		if known.has(m3u_path):
			continue
		var collection := M3uCollection.new()
		collection.m3u_path = m3u_path
		collection.name = M3uCollection.humanize_name(m3u_path.get_file().get_basename())
		discovered.append(collection)
		known[m3u_path] = true

	return discovered

func save():
	print("Saving")
	data_version = DATA_VERSION
	save_library()
	var error = ResourceSaver.save(self, SAVE_PATH)
	if error != OK:
		print("Error saving collection: ", error)
		import_notes.append("Error saving imported data: %s" % error)
		return

# Writes just the library (records, albums, artists, play counts).
func save_library():
	listens_dirty = false
	var error := GDTagLib.save_music_library(LIBRARY_PATH, {
		"music_records": music_records, "albums": albums, "artists": artists})
	if error != OK:
		print("Error saving library: ", error)
		import_notes.append("Error saving library: %s" % error)

# Persists play counts. The whole library file is rewritten, so callers still
# batch listens up rather than saving on every song change.
func save_listens():
	if listens_dirty and not importing: save_library()

func _assign_library(lib: Dictionary):
	music_records = []
	music_records.assign(lib.music_records)
	albums = []
	albums.assign(lib.albums)
	artists = []
	artists.assign(lib.artists)

func _load_library():
	var lib := GDTagLib.load_music_library(LIBRARY_PATH)
	if not lib.is_empty():
		_assign_library(lib)

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
	# Just raise the flag here — _thread_import notices it and always routes
	# through a call_deferred to _on_import_early_exit/_on_import_complete,
	# which join the thread on the main thread. Joining here would deadlock
	# when stop_import() is called from within _thread_import itself.
	_stop_flag = true

func _thread_rebuild():
	import_progress = 0
	call_deferred("_import_step_set", 2)
	build_album_images(true)
	call_deferred("_on_album_image_rebuild_complete")
	
func _thread_import():
	import_step = 0
	import_progress = 0
	_changed_album_names = {}

	# Audio, cover images and playlists all come from this one walk.
	var found := scan_music_directories(["audio", "images", "playlists"],
		func(count: int): call_deferred("_update_import_progress", float(count)), ["audio"])
	var all_paths: Array = Array(found.audio)

	# Pick up any .m3u files (ours or another app's) that showed up on disk
	# since the last scan, resolving their tracks against the library we
	# already have loaded.
	for discovered_playlist in _discover_playlists(found.playlists):
		discovered_playlist.music_records = discovered_playlist.get_music_records_from_lookup()
		playlists.append(discovered_playlist)

	if all_paths.size() == 0:
		stop_import()
		call_deferred("_on_import_early_exit")
		return

	import_start_time = Time.get_unix_time_from_system()

	# Parse-free diff: what's actually new / changed / gone since last time.
	# This also emits GDTagLib.library_update_planned -> _on_library_update_planned
	# turns the real counts into a flash message.
	# The scan's stamps save the plan a stat() per file.
	var plan := GDTagLib.plan_music_library_update(music_records, PackedStringArray(all_paths),
		{"mtimes": found.audio_mtimes, "sizes": found.audio_sizes})
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
	import_notes.append("Beginning import: %d new, %d changed, %d removed" % [plan.added.size(), plan.changed.size(), plan.removed.size()])

	# Slow, progress-reported pass: (re)parse only the files the plan flagged,
	# on a GDTagLib worker thread, and reuse the rest. GDTagLib groups them
	# into albums / artists after. Progress calls are throttled natively;
	# returning true from the callable cancels the read. One parse thread:
	# more just contend for the SD card on handhelds; GDTagLib's separate
	# prefetch thread keeps the card busy instead.
	var to_read_paths := PackedStringArray(to_read.keys())
	var read_count := to_read_paths.size()
	var built_records := GDTagLib.build_music_records(to_read_paths,
		func(done: int) -> bool:
			call_deferred("_on_record_imported", done / float(read_count))
			return _stop_flag,
		{"threads": 1})

	if _stop_flag:
		call_deferred("_on_import_early_exit")
		return

	var prev_by_path := {}
	for r: TagLibMusicRecord in music_records:
		prev_by_path[r.full_path] = r

	var built_by_path := {}
	for built: TagLibMusicRecord in built_records:
		# Play counts aren't in the tags; keep them across a re-read.
		if prev_by_path.has(built.full_path):
			built.listen_count = prev_by_path[built.full_path].listen_count
		built_by_path[built.full_path] = built
		_changed_album_names[built.album] = true

	var current: Array[TagLibMusicRecord] = []
	for p: String in all_paths:
		current.append(built_by_path[p] if built_by_path.has(p) else prev_by_path[p])

	import_progress = 0
	call_deferred("_import_step_set", 2)

	# Fast native pass: album + album-artist resolution over the whole library.
	var lib := GDTagLib.refresh_music_library(current, PackedStringArray(all_paths), {"follow_retags": false})
	_assign_library(lib)
	for artist in artists:
		Artwork.ensure_dicebear(artist.asset_id, "artist")

	build_album_images(false, found.images)
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
			
# image_paths: images found under the music directories; scanned here when
# the caller doesn't already have them.
func build_album_images(rebuild: bool = false, image_paths = null):
	var all_image_paths = image_paths if image_paths != null else scan_music_directories(["images"]).images
		
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
	if _import_thread and _import_thread.is_started():
		_import_thread.wait_to_finish()
	import_step = 0
	importing = false
	import_finished.emit()

func _on_album_image_rebuild_complete():
	if _rebuild_thread and _rebuild_thread.is_started():
		_rebuild_thread.wait_to_finish()
	import_step = 0
	save()
	UiHelper.flash_message("Album images rebuilt (%d images added)" % images_rebuilt)
	importing = false
	import_finished.emit()

func _on_import_complete():
	if _import_thread and _import_thread.is_started():
		_import_thread.wait_to_finish()
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
	
func remove_music_directory_path(path: String) -> void:
	if not music_directory_paths.has(path):
		return
	music_directory_paths.erase(path)

	var prefix := path.rstrip("/") + "/"
	var removed_records: Array[TagLibMusicRecord] = []
	var remaining_paths: PackedStringArray = []
	for record: TagLibMusicRecord in music_records:
		if record.full_path == path or record.full_path.begins_with(prefix):
			removed_records.append(record)
		else:
			remaining_paths.append(record.full_path)

	if removed_records.is_empty():
		save()
		return

	var lib := GDTagLib.refresh_music_library(music_records, remaining_paths, {"follow_retags": false})
	_assign_library(lib)

	for record in removed_records:
		M3uCollection.lookup.erase(record.full_path)
	M3uCollection.build_lookup(music_records)

	# Untracking a directory doesn't touch anything on disk, so leave every
	# .m3u file exactly as it is -- just drop the now-unresolvable tracks from
	# each playlist's in-memory view. They resolve again if the directory
	# gets re-added.
	for playlist in playlists:
		playlist.music_records = playlist.get_music_records_from_lookup()

	save()

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
