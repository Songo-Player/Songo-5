extends Node
class_name MetaDataHandler

#static var _audioMetaDataObj: AudioMetadata = AudioMetadata.new()
static var _audioMetaDataObj: GDTagLib = GDTagLib.new()

static func get_basic_metadata(file_path) -> BasicMetaData:
	var meta_data = BasicMetaData.new()
	meta_data = generic_basic_metadata(file_path, meta_data)
	return meta_data

static func generic_basic_metadata(file_path, meta_data):
	var meta_info = _audioMetaDataObj.read_audio(file_path, ["title", "album", "artist", "duration", "track", "album_artist"])

	if meta_info.has("title") && meta_info["title"]: meta_data.title = meta_info["title"]
	else: meta_data.title = file_path.get_file().get_basename()
	if meta_info.has("album") && meta_info["album"]: meta_data.album = meta_info["album"]
	if meta_info.has("artist") && meta_info["artist"]: meta_data.artist = meta_info["artist"]
	if meta_info.has("album_artist") && meta_info["album_artist"]: meta_data.album_artist = meta_info["album_artist"]
	if meta_info.has("duration") && meta_info["duration"]: meta_data.duration = float(meta_info["duration"])
	if meta_info.has("track") && meta_info["track"]: meta_data.track = meta_info["track"]
	meta_data.valid = true
	return meta_data
