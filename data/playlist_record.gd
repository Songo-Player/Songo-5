class_name PlaylistRecord extends Resource

var full_path: String
var title: String
var img_path:
	get: return full_path.get_basename()+".svg"


var music_records: Array[MusicRecord]

# RYETODO: make this have better safety
static func build_from_name(playlist_name):
	var record = PlaylistRecord.new()
	record.title = playlist_name
	record.full_path = ProjectSettings.globalize_path("user://playlists/%s.m3u" % playlist_name)
	if valid_record(record):
		# Write the file with minimal boilerplate
		var file := FileAccess.open(record.full_path, FileAccess.WRITE)
		if file:
			file.store_line("#EXTM3U")
			file.close()
			print("Created M3U playlist at: %s" % record.full_path)
		else:
			print("Failed to create M3U file at %s" % record.full_path)
			return false
		return record
	else:
		return false

static func valid_record(playlist):
	return not FileAccess.file_exists(playlist.full_path)
	
func load_music_records():
	var records: Array[MusicRecord] = []
	var m3u_path = full_path
	if not FileAccess.file_exists(m3u_path):
		push_warning("Playlist not found: %s" % m3u_path)
		return records

	var file := FileAccess.open(m3u_path, FileAccess.READ)
	if not file:
		push_error("Failed to open playlist: %s" % m3u_path)
		return records

	var lines := file.get_as_text().split("\n")
	file.close()

	var current_metadata := {}
	for i in range(lines.size()):
		var line := lines[i].strip_edges()
		if line.begins_with("#EXTINF:"):
			# Extract duration and metadata string
			var meta_part := line.substr(line.find(",") + 1).strip_edges()
			current_metadata = _parse_metadata(meta_part)
			current_metadata["raw_length"] = _extract_duration(line)
		elif not line.begins_with("#") and line != "":
			# This line should be the full_path for the previous EXTINF
			var record := MusicRecord.new()
			record.full_path = line
			record.title = current_metadata.get("title", "")
			record.album = current_metadata.get("album", "")
			record.artist = current_metadata.get("artist", "")
			record.raw_length = float(current_metadata.get("raw_length", 0))
			records.append(record)
			current_metadata = {}
	music_records = records

# --- HELPERS (static) ---

static func _extract_duration(extinf_line: String) -> float:
	var colon_index := extinf_line.find(":")
	var comma_index := extinf_line.find(",")
	if colon_index == -1 or comma_index == -1:
		return 0.0
	var duration_str := extinf_line.substr(colon_index + 1, comma_index - colon_index - 1).strip_edges()
	return float(duration_str)


static func _parse_metadata(meta_str: String) -> Dictionary:
	var result := {}
	var regex := RegEx.new()
	# Match: key="quoted value" or key=unquoted_value
	regex.compile('(\\w+)=(?:"([^"\\\\]*(?:\\\\.[^"\\\\]*)*)"|([^\\s]+))')
	
	for match_result in regex.search_all(meta_str):
		var key := match_result.get_string(1)
		# Group 2 is quoted value, group 3 is unquoted value
		var value := match_result.get_string(2) if match_result.get_string(2) != "" else match_result.get_string(3)
		# Unescape quoted values
		if match_result.get_string(2) != "":
			value = value.replace('\\"', '"').replace('\\\\', '\\')
		result[key] = value
	
	return result

static func load_playlists(directory_path: String) -> Array[PlaylistRecord]:
	directory_path = ProjectSettings.globalize_path(directory_path)
	var playlists: Array[PlaylistRecord] = []
	var dir := DirAccess.open(directory_path)
	
	if dir == null:
		push_error("Failed to open directory: %s" % directory_path)
		return playlists

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".m3u"):
			var loaded_playlist = PlaylistRecord.new()
			loaded_playlist.full_path = directory_path.path_join(file_name)
			loaded_playlist.name = file_name.get_basename()
			loaded_playlist.load_music_records()
			playlists.append(loaded_playlist)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	return playlists
