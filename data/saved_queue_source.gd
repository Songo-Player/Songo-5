extends Resource
class_name SavedQueueSource

## Which list the play queue was picked from, by type and name rather than by
## reference, so the navigation path back to it can be faked later (see
## Controller._rebuild_nav_to_playing_song). "Quit with Music" saves it so the
## next boot can do the same for the music it left playing.

const SAVE_PATH := "user://saved_queue_source.tres"

## CollectionHelper.TYPE key of the list, e.g. "ALBUM_SONGS".
@export var source_type: String = ""
## The list's name, or its .m3u path for playlists since names can repeat.
## Empty for ALL_SONGS.
@export var source_id: String = ""

## Null for lists there's no path back to, e.g. plugin collections.
static func from_collection(collection, collection_type: String) -> SavedQueueSource:
	var source = SavedQueueSource.new()
	source.source_type = collection_type
	match collection_type:
		"ALBUM_SONGS", "ARTIST_SONGS": source.source_id = collection.name
		"PLAYLIST_SONGS": source.source_id = collection.m3u_path
		"ALL_SONGS": pass
		_: return null
	return source

func save() -> void:
	var error = ResourceSaver.save(self, SAVE_PATH)
	if error != OK: push_error("Failed to save queue source: %s" % error)

static func clear_saved() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

## Loads the saved source, if any, and deletes it so it only applies once.
static func take() -> SavedQueueSource:
	if not FileAccess.file_exists(SAVE_PATH): return null
	var source = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	clear_saved()
	return source as SavedQueueSource

## The live collection this points at, or null. Only matches one that holds
## `record`, which also settles repeated names (e.g. two "Greatest Hits").
func resolve(songo_data, record):
	if record == null: return null
	var candidates: Array
	match source_type:
		"ALL_SONGS": candidates = [songo_data.music_records]
		"ALBUM_SONGS": candidates = songo_data.albums
		"ARTIST_SONGS": candidates = songo_data.artists
		"PLAYLIST_SONGS": candidates = songo_data.playlists
		_: return null
	for collection in candidates:
		if source_type == "PLAYLIST_SONGS" && collection.m3u_path != source_id: continue
		if source_type in ["ALBUM_SONGS", "ARTIST_SONGS"] && collection.name != source_id: continue
		if _holds(collection, record): return collection
	return null

# Whether `collection` holds `record`'s file. Albums, artists and All Songs
# answer natively instead of making a record per track to compare.
static func _holds(collection, record) -> bool:
	if collection is TagLibTrackList: return collection.find_path(record.full_path) >= 0
	if collection is TagLibTrackGroup: return collection.has_track(record)
	var records = collection if collection is Array else collection.music_records
	for collection_record in records:
		if collection_record.full_path == record.full_path: return true
	return false

## The main menu action whose list holds this source's list, e.g. albums_index
## for an album. For ALL_SONGS the index list is the source itself.
func index_action() -> Callable:
	match source_type:
		"ALBUM_SONGS": return Controller.albums_index
		"ARTIST_SONGS": return Controller.artists_index
		"PLAYLIST_SONGS": return Controller.playlists_index
	return Controller.songs_index
