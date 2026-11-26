extends RefCounted

## Album covers a browser built while sending songs, kept until the import that
## uses them. Named by the song's path, so there's no index to keep. Safe on any
## thread.

const DIR := "user://file_transfer_covers"
const MAX_BYTES := 1024 * 1024
# The shorter side is 500, as in Songo's own covers; the longer is bounded here
const MAX_SIDE := 2000
const EXTS := ["webp", "jpg"]

## The cover sent with a song, or "".
static func find(song_path: String) -> String:
	for ext in EXTS:
		var path := _path(song_path, ext)
		if FileAccess.file_exists(path): return path
	return ""

## Keeps a WebP or JPEG cover for a song. False if it isn't a usable image.
static func store(song_path: String, data: PackedByteArray) -> bool:
	var image := Image.new()
	var ext := ""
	if data.size() > 12 and data.slice(0, 4).get_string_from_ascii() == "RIFF" and data.slice(8, 12).get_string_from_ascii() == "WEBP":
		if image.load_webp_from_buffer(data) == OK: ext = "webp"
	elif data.size() > 3 and data[0] == 0xFF and data[1] == 0xD8 and data[2] == 0xFF:
		if image.load_jpg_from_buffer(data) == OK: ext = "jpg"
	if ext == "" or image.is_empty() or maxi(image.get_width(), image.get_height()) > MAX_SIDE: return false
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := _path(song_path, ext)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(data)
	file.flush()
	var err := file.get_error()
	file.close()
	if err != OK: DirAccess.remove_absolute(path)
	return err == OK

static func clear() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null: return
	for file_name in dir.get_files():
		if file_name.get_extension() in EXTS: dir.remove(file_name)

static func _path(song_path: String, ext: String) -> String:
	return "%s/%s.%s" % [DIR, song_path.md5_text(), ext]
