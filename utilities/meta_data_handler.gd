extends Node
class_name MetaDataHandler

static var _audioMetaDataObj: AudioMetadata = AudioMetadata.new()

static func get_basic_metadata(file_path) -> BasicMetaData:
	var meta_data = BasicMetaData.new()
	meta_data = generic_basic_metadata(file_path, meta_data)
	#var file_type = file_path.get_extension()
	#if file_type == "mp3":
	#	meta_data = mp3_basic_metadata(file_path, meta_data)
	#elif file_type == "flac":
	#	meta_data = flac_basic_metadata(file_path, meta_data)
	#elif file_type == "ogg":
	#	meta_data = ogg_basic_metadata(file_path, meta_data)
	#else:
	#	meta_data = MetaDataHandlerFFprobe.get_basic_metadata(file_path)
		#meta_data = generic_basic_metadata(file_path, meta_data)
	return meta_data

static func mp3_basic_metadata(file_path, meta_data):
	var meta_info = _audioMetaDataObj.read_mp3(file_path, ["title", "album", "artist", "duration", "track"])
	
	if meta_info.has("title") && meta_info["title"]: meta_data.title = meta_info["title"]
	else: meta_data.title = file_path.get_file().get_basename()
	if meta_info.has("album") && meta_info["album"]: meta_data.album = meta_info["album"]
	if meta_info.has("artist") && meta_info["artist"]: meta_data.artist = meta_info["artist"]
	if meta_info.has("duration") && meta_info["duration"]: meta_data.duration = float(meta_info["duration"])
	if meta_info.has("track") && meta_info["track"]: meta_data.track = meta_info["track"]
	meta_data.valid = true
	return meta_data

static func flac_basic_metadata(file_path, meta_data):
	var meta_info = _audioMetaDataObj.read_flac(file_path, ["title", "album", "artist", "duration", "track"])
	
	if meta_info.has("title") && meta_info["title"]: meta_data.title = meta_info["title"]
	else: meta_data.title = file_path.get_file().get_basename()
	if meta_info.has("album") && meta_info["album"]: meta_data.album = meta_info["album"]
	if meta_info.has("artist") && meta_info["artist"]: meta_data.artist = meta_info["artist"]
	if meta_info.has("duration") && meta_info["duration"]: meta_data.duration = float(meta_info["duration"])
	if meta_info.has("track") && meta_info["track"]: meta_data.track = meta_info["track"]
	meta_data.valid = true
	return meta_data
	
static func ogg_basic_metadata(file_path, meta_data):
	var meta_info = _audioMetaDataObj.read_ogg(file_path, ["title", "album", "artist", "duration", "track"])
	
	if meta_info.has("title") && meta_info["title"]: meta_data.title = meta_info["title"]
	else: meta_data.title = file_path.get_file().get_basename()
	if meta_info.has("album") && meta_info["album"]: meta_data.album = meta_info["album"]
	if meta_info.has("artist") && meta_info["artist"]: meta_data.artist = meta_info["artist"]
	if meta_info.has("duration") && meta_info["duration"]: meta_data.duration = float(meta_info["duration"])
	if meta_info.has("track") && meta_info["track"]: meta_data.track = meta_info["track"]
	meta_data.valid = true
	return meta_data
	
static func generic_basic_metadata(file_path, meta_data):
	var meta_info = _audioMetaDataObj.read_audio(file_path, ["title", "album", "artist", "duration", "track"])

	if meta_info.has("title") && meta_info["title"]: meta_data.title = meta_info["title"]
	else: meta_data.title = file_path.get_file().get_basename()
	if meta_info.has("album") && meta_info["album"]: meta_data.album = meta_info["album"]
	if meta_info.has("artist") && meta_info["artist"]: meta_data.artist = meta_info["artist"]
	if meta_info.has("duration") && meta_info["duration"]: meta_data.duration = float(meta_info["duration"])
	if meta_info.has("track") && meta_info["track"]: meta_data.track = meta_info["track"]
	meta_data.valid = true
	return meta_data

#class BasicMetaData:
#	var valid: bool = false
#	var duration: float = 0.0
#	var title: String = "Title (Metadata Failure)"
#	var album: String = "Unknown Album"
#	var artist: String = "Unknown Artist"
#	var track: int = 0
