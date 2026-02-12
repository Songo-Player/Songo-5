extends Node
class_name MetaDataHandlerFFprobe

static func get_basic_metadata(file_path: String) -> BasicMetaData:
	var meta := BasicMetaData.new()
	var info := _probe(file_path)

	if info.is_empty():
		meta.title = file_path.get_file().get_basename()
		return meta

	# Duration
	if info.has("duration"):
		meta.duration = float(info["duration"])
	
	#print("Info for: %s" % file_path)
	#print(info)
	# Tags
	var tags = info.get("tags", {})

	meta.title = tags.get("title", file_path.get_file().get_basename())
	meta.artist = tags.get("artist", "Unknown Artist")
	meta.album = tags.get("album", "Unknown Album")

	if tags.has("track"):
		meta.track = _parse_track(tags["track"])

	meta.valid = true
	return meta


static func _probe(file_path: String) -> Dictionary:
	var output := []
	var args := [
		"-v", "quiet",
		"-print_format", "json",
		"-show_entries", "format=duration:format_tags=title,artist,album,track",
		#"-show_format",
		file_path
	]
	var cmd = "ffprobe"
	if OS.get_name() != "Windows":
		var bin_path = OS.get_environment("SONGO_BINARIES_DIR")
		cmd = "%s/ffmpeg/ffprobe" % bin_path
	var exit_code := OS.execute(cmd, args, output, true)

	if exit_code != 0 or output.is_empty():
		return {}

	var json_text = output[0]
	var parsed = JSON.parse_string(json_text)

	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	var result := {}

	if parsed.has("format"):
		var fmt = parsed["format"]

		if fmt.has("duration"):
			result["duration"] = fmt["duration"]

		if fmt.has("tags"):
			result["tags"] = fmt["tags"]

	return result


static func _parse_track(track_value) -> int:
	# Handles "3", "3/12", etc.
	if typeof(track_value) == TYPE_STRING:
		var parts = track_value.split("/")
		return int(parts[0])
	return int(track_value)
	
static func get_embedded_image(file_path: String) -> Image:
	# Step 1: Check if the file has an attached picture stream
	var output := []
	var args := [
		"-v", "quiet",
		"-print_format", "json",
		"-show_streams",
		file_path
	]

	var cmd = "ffprobe"
	if OS.get_name() != "Windows":
		var bin_path = OS.get_environment("SONGO_BINARIES_DIR")
		cmd = "%s/ffmpeg/ffprobe" % bin_path

	var exit_code := OS.execute(cmd, args, output, true)
	if exit_code != 0 or output.is_empty():
		return null

	var parsed = JSON.parse_string(output[0])
	if typeof(parsed) != TYPE_DICTIONARY or !parsed.has("streams"):
		return null

	var has_cover := false
	for stream in parsed["streams"]:
		if stream.get("disposition", {}).get("attached_pic", 0) == 1:
			has_cover = true
			break

	if !has_cover:
		return null

	# Step 2: Extract the embedded image using ffmpeg
	var tmp_path := "user://cover_art_%s.jpg" % str(Time.get_unix_time_from_system())

	var ffmpeg_cmd = "ffmpeg"
	if OS.get_name() != "Windows":
		var bin_path = OS.get_environment("SONGO_BINARIES_DIR")
		ffmpeg_cmd = "%s/ffmpeg/ffmpeg" % bin_path

	var ffmpeg_args := [
		"-y",                # overwrite
		"-i", file_path,
		"-an",               # no audio
		"-vcodec", "copy",   # copy image without re-encoding
		tmp_path
	]

	output.clear()
	exit_code = OS.execute(ffmpeg_cmd, ffmpeg_args, output, true)
	if exit_code != 0 or !FileAccess.file_exists(tmp_path):
		print("Problem?")
		return null

	# Step 3: Load into Godot Image
	var image := Image.new()
	var err := image.load(tmp_path)
	print("Got here in imahe")
	# Cleanup temp file
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))

	if err != OK:
		return null

	return image
