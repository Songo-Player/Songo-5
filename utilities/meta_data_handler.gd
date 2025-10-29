extends Node
class_name MetaDataHandler

static var _audioMetaDataObj: AudioMetadata = AudioMetadata.new()

static func get_basic_metadata(file_path) -> BasicMetaData:
	var meta_data = BasicMetaData.new()
	var file_type = file_path.get_extension()
	if file_type == "mp3":
		meta_data = mp3_basic_metadata(file_path, meta_data)
	elif file_type == "flac":
		meta_data = flac_basic_metadata(file_path, meta_data)
	else:
		print("Bad file type")
	return meta_data

static func mp3_basic_metadata(file_path, meta_data):
	var meta_info = _audioMetaDataObj.read_mp3(file_path, ["title", "album", "artist", "duration"])
	
	if meta_info.has("title"): meta_data.title = meta_info["title"]
	else: meta_data.title = file_path.get_file().get_basename()
	if meta_info.has("album"): meta_data.album = meta_info["album"]
	if meta_info.has("artist"): meta_data.artist = meta_info["artist"]
	if meta_info.has("duration"): meta_data.duration = float(meta_info["duration"])
	meta_data.valid = true
	return meta_data

static func flac_basic_metadata(file_path, meta_data):
	var meta_info = _audioMetaDataObj.read_flac(file_path, ["title", "album", "artist", "duration"])
	
	if meta_info.has("title"): meta_data.title = meta_info["title"]
	else: meta_data.title = file_path.get_file().get_basename()
	if meta_info.has("album"): meta_data.album = meta_info["album"]
	if meta_info.has("artist"): meta_data.artist = meta_info["artist"]
	if meta_info.has("duration"): meta_data.duration = float(meta_info["duration"])
	meta_data.valid = true
	return meta_data

class BasicMetaData:
	var valid: bool = false
	var duration: float = 0.0
	var title: String = "Title (Metadata Failure)"
	var album: String = "Unknown Album"
	var artist: String = "Unknown Artist"
