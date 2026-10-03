extends Resource
class_name M3uCollection

signal item_removed(resource)

var name: String
var m3u_path: String
# Where generated placeholder images live. Plugin collections point this
# elsewhere so they don't collide with, or get wiped along with, playlists.
var image_dir: String = "user://playlist_images"
var music_records: Array[TagLibMusicRecord]
var img_path:
	get: return _resolve_img_path()

# The playlist's on-disk file name (without extension). Kept distinct from
# `name` so image lookups stay pinned to the actual .m3u file even if `name`
# is ever prettified for display.
var file_stem:
	get: return m3u_path.get_file().get_basename()

static var lookup = {}

var img:
	get:
		var image = Image.new()
		image.load(img_path)
		return image

# Looks for a playlist image in priority order: an image living next to the
# .m3u file (so imported playlists from other apps keep working), then a
# generated placeholder.
func _resolve_img_path() -> String:
	if m3u_path.is_empty():
		return ""

	var image_extensions := ["png", "svg", "webp", "jpeg", "jpg"]

	var adjacent_base := m3u_path.get_basename()
	for ext in image_extensions:
		var adjacent_path := "%s.%s" % [adjacent_base, ext]
		if FileAccess.file_exists(adjacent_path):
			return adjacent_path

	for ext in image_extensions:
		var generated_path := "%s/%s.%s" % [image_dir, file_stem, ext]
		if FileAccess.file_exists(generated_path):
			return generated_path

	return ""

# Turns a raw file basename (e.g. "lofi_jamz") into a display-friendly name
# (e.g. "Lofi jamz") for playlists discovered on disk rather than created
# in-app.
static func humanize_name(raw_name: String) -> String:
	var humanized := raw_name.replace("_", " ").strip_edges()
	if humanized.is_empty():
		return humanized
	return humanized[0].to_upper() + humanized.substr(1)

# --- Static factory method ---
# Creates a new .m3u directly inside the user's first configured music
# directory (instead of the app's private user:// sandbox) so the playlist
# is a normal file other music apps can see and use.
static func create_collection(name: String) -> M3uCollection:
	if name.contains("/") or name.contains("\\"):
		push_error("Playlist name can't contain path separators: %s" % name)
		return null

	var songo_data := SongoDataResource.get_instance()
	if songo_data.music_directory_paths.is_empty():
		push_error("Add a music directory before creating a playlist.")
		return null

	var root_dir: String = songo_data.music_directory_paths[0]
	if not DirAccess.dir_exists_absolute(root_dir):
		push_error("Music directory does not exist: %s" % root_dir)
		return null

	var m3u_path := root_dir.path_join("%s.m3u" % name)

	# Write initial header (overwrite if it exists)
	var file := FileAccess.open(m3u_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for writing: %s" % m3u_path)
		return null

	file.store_line("#EXTM3U")
	file.store_line("")  # blank line for readability
	file.close()

	# Return initialized instance
	var instance := M3uCollection.new()
	instance.name = name
	instance.m3u_path = m3u_path
	return instance

# --- Instance Methods ---

# Adds a track (absolute path). No EXTINF or metadata; prevents duplicates.
# Stored on disk as a path relative to this playlist's own .m3u location.
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

	var relative_path := _to_relative(absolute_track_path.strip_edges())

	if relative_path in track_lines:
		# already present
		return

	track_lines.append(relative_path)
	_write_file(header_lines, track_lines)
	print("Added track: %s" % relative_path)

func add_tracks(operating_music_records: Array[TagLibMusicRecord]) -> int:
	var modified_item_count = 0
	var content := _read_lines()
	var header_lines := _extract_header_lines(content)
	var track_lines := _extract_track_lines(content)

	for music_record in operating_music_records:
		var record = lookup[music_record.full_path]
		var relative_path := _to_relative(music_record.full_path)
		if record != null && !(relative_path in track_lines):
			music_records.append(record)
			track_lines.append(relative_path)
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

	var relative_path := _to_relative(absolute_track_path.strip_edges())

	# Filter out exact matches
	var new_tracks := []
	for t in track_lines:
		if t != relative_path:
			new_tracks.append(t)

	_write_file(header_lines, new_tracks)

	item_removed.emit(lookup[absolute_track_path])

func remove_tracks(operating_music_records: Array[TagLibMusicRecord]) -> int:

	var modified_item_count = 0
	var content := _read_lines()
	var header_lines := _extract_header_lines(content)
	var track_lines := _extract_track_lines(content)
	var removed_lines = []

	for music_record in operating_music_records:
		var record = lookup[music_record.full_path]
		if record != null:
			var relative_path := _to_relative(music_record.full_path)
			if relative_path in track_lines:
				music_records.erase(record)
				modified_item_count += 1
				removed_lines.append(relative_path)


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
	var relative_path := _to_relative(absolute_track_path.strip_edges())
	return relative_path in track_lines


func get_music_records_from_lookup() -> Array[TagLibMusicRecord]:
	if m3u_path == "":
		push_error("Collection not initialized properly.")
		return []

	var track_paths := _extract_track_lines(_read_lines())
	if track_paths.is_empty():
		return []

	# Build ordered filtered result
	var result: Array[TagLibMusicRecord] = []
	for path in track_paths:
		var abs_path := _to_absolute(str(path))
		if lookup.has(abs_path):
			result.append(lookup[abs_path])

	return result

func get_collection_overlap(music_array: Array[TagLibMusicRecord]) -> float:
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

# Converts an absolute track path into a path relative to this playlist's
# .m3u file, so the file stays portable and usable from wherever it lives
# (including a folder other music apps also read/write it from).
func _to_relative(absolute_path: String) -> String:
	return _relative_path(absolute_path.simplify_path(), m3u_path.get_base_dir().simplify_path())

# Resolves a path stored in the .m3u (relative or absolute, "/" or "\"
# separated) back into an absolute path usable as a `lookup` key.
func _to_absolute(stored_path: String) -> String:
	var p := stored_path.strip_edges().replace("\\", "/")
	if p.is_empty():
		return ""
	if p.is_absolute_path():
		return p.simplify_path()
	return m3u_path.get_base_dir().path_join(p).simplify_path()

# Builds `target_path` relative to `base_dir`, using "../" hops as needed.
# The two directories aren't assumed to share a common root (a track can
# live under a different music directory entirely).
static func _relative_path(target_path: String, base_dir: String) -> String:
	var target_parts := target_path.split("/", false)
	var base_parts := base_dir.split("/", false)

	var common := 0
	while common < target_parts.size() and common < base_parts.size() and target_parts[common] == base_parts[common]:
		common += 1

	var rel_parts: Array = []
	for i in range(common, base_parts.size()):
		rel_parts.append("..")
	for i in range(common, target_parts.size()):
		rel_parts.append(target_parts[i])

	if rel_parts.is_empty():
		return target_parts[-1]

	return "/".join(rel_parts)

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

func set_dicebear_image():
	var source_img_path = "res://assets/dicebear/shapes/shapes-%d.svg" % randi_range(0, 199)
	var save_path := "%s/%s.svg" % [image_dir, file_stem]

	if FileAccess.file_exists(save_path):
		return false

	if not DirAccess.dir_exists_absolute(image_dir):
		DirAccess.make_dir_recursive_absolute(image_dir)


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
