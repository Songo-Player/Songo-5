extends Resource
class_name M3uCollection

signal item_removed(resource)

var name: String
var m3u_path: String
var music_records: Array[MusicRecord]
var img_path:
	get: return _get_playlist_image_path()
	#get: return get_img_path()
	
static var lookup = {}
	
func get_img_path():
	if m3u_path.is_empty():
		return ""
		
	var base_path = m3u_path.trim_suffix(".m3u")
	var image_extensions = ["png", "svg", "webp", "jpeg", "jpg"]
		
	for ext in image_extensions:
		var potential_path = base_path + "." + ext
		if FileAccess.file_exists(potential_path):
			return potential_path
	return ""
	
func _get_playlist_image_path():
	var base_path = "user://playlist_images"
	var image_extensions = ["png", "svg", "webp", "jpeg", "jpg"]
	for ext in image_extensions:
		var file_path = "%s/%s-override.%s" % [base_path, name, ext]
		if FileAccess.file_exists(file_path): return file_path

	for ext in image_extensions:
		var file_path = "%s/%s.%s" % [base_path, name, ext]
		if FileAccess.file_exists(file_path): return file_path
	
	return ""

var img:
	get: 
		var image = Image.new()
		image.load(img_path)
		return image
	
# --- Static factory method ---
static func create_collection(collection_type: String, name: String) -> M3uCollection:
	var dir_path := "user://%s" % collection_type
	var m3u_path := "%s/%s.m3u" % [dir_path, name]

	# Ensure directory exists (make_dir_recursive works on a DirAccess)
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("Failed to open user:// DirAccess")
		return null

	if not dir.dir_exists(dir_path):
		var err := dir.make_dir_recursive(dir_path)
		if err != OK:
			push_error("Failed to create directory: %s" % dir_path)
			return null

	# Write initial header (overwrite if it exists)
	var file := FileAccess.open(m3u_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for writing: %s" % m3u_path)
		return null

	file.store_line("#EXTM3U")
	file.store_line("")  # blank line for readability
	file.close()
	
	#WikiScrape.fetch_dicebear_collection_img(collection_type, name, "shapes")
	# Return initialized instance
	var instance := M3uCollection.new()
	instance.name = name
	instance.m3u_path = m3u_path
	return instance

# --- Instance Methods ---

# Adds a track (absolute path). No EXTINF or metadata; prevents duplicates.
func add_track(absolute_track_path: String) -> void:
	if m3u_path == "":
		push_error("Collection not initialized properly.")
		return
	var record = lookup[absolute_track_path]
	if record == null:
		UiHelper.flash_message("Failed to add to playlist")
		return
	music_records.append(record)
	# Read existing content
	var content := _read_lines()
	var header_lines := _extract_header_lines(content)
	var track_lines := _extract_track_lines(content)

	# Normalize
	absolute_track_path = absolute_track_path.strip_edges()

	if absolute_track_path in track_lines:
		# already present
		return

	track_lines.append(absolute_track_path)
	_write_file(header_lines, track_lines)
	print("Added track: %s" % absolute_track_path)

func add_tracks(operating_music_records: Array[MusicRecord]) -> int:
	var modified_item_count = 0
	var content := _read_lines()
	var header_lines := _extract_header_lines(content)
	var track_lines := _extract_track_lines(content)

	for music_record in operating_music_records:
		var record = lookup[music_record.full_path]
		if record != null && !(music_record.full_path in track_lines):
			music_records.append(record)
			track_lines.append(music_record.full_path)
			modified_item_count += 1
			
	_write_file(header_lines, track_lines)
	print("Added tracks: %d" % modified_item_count)
	return modified_item_count
	
	
# Removes all exact-matching track lines
func remove_track(absolute_track_path: String) -> void:
	if m3u_path == "":
		push_error("Collection not initialized properly.")
		return
	var record = lookup[absolute_track_path]
	if record == null:
		UiHelper.flash_message("Failed to remove from playlist")
		return
	music_records.erase(record)
	var content := _read_lines()
	var header_lines := _extract_header_lines(content)
	var track_lines := _extract_track_lines(content)

	absolute_track_path = absolute_track_path.strip_edges()

	# Filter out exact matches
	var new_tracks := []
	for t in track_lines:
		if t != absolute_track_path:
			new_tracks.append(t)

	_write_file(header_lines, new_tracks)
	
	item_removed.emit(lookup[absolute_track_path])
	
func remove_tracks(operating_music_records: Array[MusicRecord]) -> int:
	
	var modified_item_count = 0
	var content := _read_lines()
	var header_lines := _extract_header_lines(content)
	var track_lines := _extract_track_lines(content)
	var removed_lines = []

	for music_record in operating_music_records:
		var record = lookup[music_record.full_path]
		if record != null:
			if music_record.full_path in track_lines:
				music_records.erase(record)
				modified_item_count += 1
				removed_lines.append(music_record.full_path)


	# Filter out exact matches
	var new_tracks := []
	for t in track_lines:
		if !(t in removed_lines):
			new_tracks.append(t)

	_write_file(header_lines, new_tracks)
	return modified_item_count
	

# Returns true if exact track path exists
func contains_track(absolute_track_path: String) -> bool:
	if m3u_path == "":
		push_error("Collection not initialized properly.")
		return false

	var content := _read_lines()
	var track_lines := _extract_track_lines(content)
	absolute_track_path = absolute_track_path.strip_edges()
	return absolute_track_path in track_lines


func get_music_records_from_lookup() -> Array[MusicRecord]:
	if m3u_path == "":
		push_error("Collection not initialized properly.")
		return []

	var track_paths := _extract_track_lines(_read_lines())
	if track_paths.is_empty():
		return []
	
	# Build ordered filtered result
	var result: Array[MusicRecord] = []
	for path in track_paths:
		var clean := str(path).strip_edges()
		if lookup.has(clean):
			result.append(lookup[clean])

	return result
	
func get_collection_overlap(music_array: Array[MusicRecord]) -> float:
	var matches = 0
	for music in music_array:
		if music_records.has(music):
			matches += 1
	return float(matches) / music_array.size()
	
# --- Helpers ---
static func build_lookup(music_array):
	for record in music_array:
		if record is Resource and record.has_method("get"):
			var fp := str(record.full_path).strip_edges()
			lookup[fp] = record
			
# Reads file and returns array of raw lines (preserves order, including comments and blanks)
func _read_lines() -> Array:
	var result := []
	if not FileAccess.file_exists(m3u_path):
		return result

	var file := FileAccess.open(m3u_path, FileAccess.READ)
	if file == null:
		push_error("Failed to read file: %s" % m3u_path)
		return result

	while not file.eof_reached():
		result.append(file.get_line())
	file.close()
	return result


# Extract header comment lines (all lines that start with '#' in order,
# but stops when first non-comment non-blank line is seen)
func _extract_header_lines(lines: Array) -> Array:
	var headers := []
	for line in lines:
		var s := str(line)
		if s.strip_edges() == "":
			# keep blank lines that appear before tracks (preserve readability)
			headers.append(s)
			continue
		if s.begins_with("#"):
			headers.append(s)
			continue
		# hit first non-comment (a track), stop collecting headers
		break
	# If header is empty, at least add a minimal header so file stays valid
	if headers == []:
		headers = ["#EXTM3U", ""]
	return headers


# Extract only track lines (non-comment, non-empty)
func _extract_track_lines(lines: Array) -> Array:
	var tracks := []
	for line in lines:
		var s := str(line).strip_edges()
		if s == "" or s.begins_with("#"):
			continue
		tracks.append(s)
	return tracks


# Rewrite the file with given header_lines and track_lines
func _write_file(header_lines: Array, track_lines: Array) -> void:
	var file := FileAccess.open(m3u_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for write: %s" % m3u_path)
		return

	# Write headers
	for h in header_lines:
		file.store_line(h)

	# Ensure a blank line between header and tracks if none present
	if header_lines == [] or header_lines[-1].strip_edges() != "":
		file.store_line("")

	# Write tracks
	for t in track_lines:
		file.store_line(t)

	file.close()

static func load_collection_type(type: String) -> Array[M3uCollection]:
	var directory_path = ProjectSettings.globalize_path("user://%s" % type)
	var collections: Array[M3uCollection] = []
	var dir := DirAccess.open(directory_path)
	
	if dir == null:
		push_error("Failed to open directory: %s" % directory_path)
		return collections

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".m3u"):
			var loaded_collection = M3uCollection.new()
			loaded_collection.m3u_path = directory_path.path_join(file_name)
			loaded_collection.name = file_name.get_basename()
			collections.append(loaded_collection)
		file_name = dir.get_next()
	dir.list_dir_end()
	return collections
	
func set_dicebear_image():
	var source_img_path = "res://assets/dicebear/shapes/shapes-%d.svg" % randi_range(0, 199)
	#var save_path = m3u_path.get_basename()+".svg"
	
	var save_path := "user://playlist_images/%s.svg" % name

	var dir := DirAccess.open("user://")
	if dir.dir_exists("playlist_images") and FileAccess.file_exists(save_path):
		return false

	if not dir.dir_exists("playlist_images"):
		dir.make_dir("playlist_images")
	
	
	if not FileAccess.file_exists(source_img_path):
		print("Trying to load non-existant image: %s" % source_img_path)
		return false

	var src := FileAccess.open(source_img_path, FileAccess.READ)
	var data := src.get_buffer(src.get_length())
	src.close()

	var dst := FileAccess.open(save_path, FileAccess.WRITE)
	dst.store_buffer(data)
	dst.close()

	return true
