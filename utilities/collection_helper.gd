extends Node


var _list_items = null
var _current_collection = null
var target_item_index = -1
var current_collection:
	get: return _current_collection
	set(collection): _set_current_collection(collection)
	
var sort_options:
	get: return SORT_OPTION_ARR[_get_collection_type()]
	
var collection_name:
	get: return _get_collection_name()
	
var collection_size:
	get: return _get_collection_size()
	
var collection_image_texture:
	get: return _get_collection_image()
	
enum TYPE {
	INVALID,
	ALL_SONGS,
	ALBUMS,
	ARTISTS,
	PLAYLISTS,
	ALBUM_SONGS,
	ARTIST_SONGS,
	PLAYLIST_SONGS
}
const SORT_OPTION_ARR = [
	[], # INVALID
	["song_alpha_asc", "song_alpha_desc"], # ALL_SONGS
	["album_alpha_asc", "album_alpha_desc", "album_artist_alpha_asc", "album_artist_alpha_desc"], # ALBUMS
	["artist_alpha_asc", "artist_alpha_desc", "music_record_count_asc", "music_record_count_desc"], # ARTISTS
	["playlist_alpha_asc", "playlist_alpha_desc", "music_record_count_asc", "music_record_count_desc"], # PLAYLISTS
	["song_track_asc", "song_track_desc", "song_alpha_asc", "song_alpha_desc"], # ALBUM_SONGS
	["song_alpha_asc", "song_alpha_desc"], # ARTIST_SONGS
	["song_alpha_asc", "song_alpha_desc"], # PLAYLIST_SONGS
]

var collection_type:
	get: return TYPE.keys()[_get_collection_type()]

var target_item:
	get: return _get_target_item()
	
func _set_current_collection(collection):
	if collection == null:
		_current_collection = null
		_list_items = null
	else:
		_current_collection = collection
		if "music_records" in _current_collection:
			_list_items = _current_collection.music_records
		else:
			_list_items = _current_collection


func _get_collection_type():
	var coll = _current_collection
	
	if coll is Array[MusicRecord]: return TYPE.ALL_SONGS
	if coll is Array[AlbumRecord]: return TYPE.ALBUMS
	if coll is Array[ArtistRecord]: return TYPE.ARTISTS
	if coll is Array[M3uCollection]: return TYPE.PLAYLISTS
	if coll is AlbumRecord: return TYPE.ALBUM_SONGS
	if coll is ArtistRecord: return TYPE.ARTIST_SONGS
	if coll is M3uCollection: return TYPE.PLAYLIST_SONGS
	
	return TYPE.INVALID

func _get_collection_name():
	match _get_collection_type():
		TYPE.INVALID: return "Collection"
		TYPE.ALL_SONGS: return "All Songs"
		TYPE.ALBUMS: return "Albums"
		TYPE.ARTISTS: return "Artists"
		TYPE.PLAYLISTS: return "Playlists"
		TYPE.ALBUM_SONGS, TYPE.ARTIST_SONGS, TYPE.PLAYLIST_SONGS: return _current_collection.name
	
func _get_collection_size():
	if _list_items:
		return _list_items.size()
	else:
		return 0
		
func _get_target_item():
	if _list_items && target_item_index >= 0:
		return _list_items[target_item_index]
	return false
	
func _get_collection_image():
	var base_image = false
	# Good lord clean this up, settle on one attr name
	match _get_collection_type():
		TYPE.ALBUM_SONGS: base_image = _current_collection.cover
		TYPE.ARTIST_SONGS: base_image = _current_collection.artist_image
		TYPE.PLAYLIST_SONGS: base_image = _current_collection.img
	
	if base_image:
		return ImageTexture.create_from_image(base_image)
	return null
	
