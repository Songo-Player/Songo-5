extends M3uCollection

## One station .m3u. Each stream URL in it becomes a record in music_records,
## so the song view's left/right moves between them. Extends M3uCollection so
## themes render it with their playlist collection button.

const DEFAULT_SUBTITLE = "Live radio"
const IMAGE_DIR = "user://web_radio_images"

var plugin

func load_m3u(path: String) -> bool:
	m3u_path = path
	image_dir = IMAGE_DIR
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("WebRadio: couldn't read %s" % path)
		return false

	var title := ""
	var genre := ""
	var titles := {}
	for raw_line in file.get_as_text().split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("#EXTINF"):
			title = line.substr(line.find(",") + 1).strip_edges()
			genre = ""
		elif line.begins_with("#EXTGENRE:"):
			genre = line.trim_prefix("#EXTGENRE:").strip_edges()
		elif line.is_empty() or line.begins_with("#"):
			continue
		else:
			music_records.append(_make_record(line, title, genre))
			titles[title] = true

	# Single-station files are named by their #EXTINF; "-Stations" files list
	# several stations from one broadcaster, so fall back to the file name.
	if titles.size() == 1 and not title.is_empty():
		name = title
	else:
		name = file_stem.trim_suffix("-Stations").replace("-", " ")

	for i in range(music_records.size()):
		var record: TagLibMusicRecord = music_records[i]
		record.track = i + 1
		if record.title.is_empty(): record.title = name
	return not music_records.is_empty()

func _make_record(url: String, title: String, genre: String) -> TagLibMusicRecord:
	var record := SongoMusicRecord.new()
	record.full_path = url
	record.title = title
	record.genre = genre
	record.artist = genre if not genre.is_empty() else DEFAULT_SUBTITLE
	# Shows which mirror/bitrate is playing when a station has several streams.
	record.album = url.get_slice("://", 1)
	record.raw_length = -1.0
	record.set_meta("default_artist", record.artist)
	return record

func has_record(record) -> bool:
	return music_records.has(record)

# Called by the collection button in place of opening a song list.
func activate():
	plugin.play_station(self)

func get_list_summary() -> String:
	var count := music_records.size()
	var summary := "%d stream%s" % [count, "" if count == 1 else "s"]
	var genre: String = music_records[0].genre if count > 0 else ""
	if not genre.is_empty(): summary += " · %s" % genre
	return summary
