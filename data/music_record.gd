class_name MusicRecord extends Resource

@export var full_path: String
@export var title: String
@export var raw_length: float
@export var album: String
@export var artist: String
@export var track: int
var album_cover_texture #Set this manually before access

var length: String:
	get: return formatted_duration(raw_length)
	
var title_with_track: String:
	get: return _title_with_track()
	
func formatted_duration(length_sec: float):
	var minutes: int = int(length_sec) / 60
	var seconds: int = int(length_sec) % 60
	return "%d:%02d" % [minutes, seconds]
	
var image_texture: 
	get: return _get_image_texture()
	
func _get_image_texture():
	return AudioMetadata.get_cover_image(full_path)
	#var file_type = full_path.get_extension()
	#if file_type == "mp3":
	#	return AudioMetadata.get_mp3_image(full_path)
	#elif file_type == "flac":
	#	return AudioMetadata.get_flac_image(full_path)
	#elif file_type == "ogg":
	#	return AudioMetadata.get_ogg_image(full_path)
	#else:
	#	print("Unkown file type")
	#	return false
	
func _title_with_track():
	if track == 0: return title

	return "%02d. %s" % [track, title]

# Removes this song from an .m3u playlist, if present
func remove_from_playlist(m3u_path: String) -> void:
	if not FileAccess.file_exists(m3u_path):
		print("Playlist does not exist: ", m3u_path)
		return

	var read_file := FileAccess.open(m3u_path, FileAccess.READ)
	if not read_file:
		push_error("Failed to open playlist for reading: %s" % m3u_path)
		return

	var lines := read_file.get_as_text().split("\n")
	read_file.close()

	var new_lines: Array = []
	var skip_next := false
	var removed := false

	for i in range(lines.size()):
		var line := lines[i].strip_edges()
		if skip_next:
			skip_next = false
			continue

		# If this line matches the song path, remove this and its preceding EXTINF
		if line == full_path:
			# Try to skip the #EXTINF line before it if possible
			if i > 0 and lines[i - 1].begins_with("#EXTINF"):
				new_lines.pop_back()  # remove last added EXTINF
			removed = true
			continue

		new_lines.append(lines[i])

	# Rewrite playlist if something changed
	if removed:
		var write_file := FileAccess.open(m3u_path, FileAccess.WRITE)
		if write_file:
			write_file.store_string("\n".join(new_lines))
			write_file.close()
			print("Removed from playlist: ", title)
		else:
			push_error("Failed to open playlist for writing: %s" % m3u_path)
	else:
		print("Song not found in playlist: ", title)
		
# --- STATIC PARSER METHOD ---

static func m3u_to_music_records(m3u_path: String) -> Array[MusicRecord]:
	var records: Array[MusicRecord] = []

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

	return records

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
