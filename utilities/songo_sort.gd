extends Node
class_name SongoSort

const TYPES = {
	"song_alpha_asc": "Sorted alphabetically",
	"song_alpha_desc": "Sorted alphabetically",
	"song_track_asc": "Sorted by track number",
	"song_track_desc": "Sorted by track number",
	"album_alpha_asc": "Sorted alphabetically",
	"album_alpha_desc": "Sorted alphabetically",
	"artist_alpha_asc": "Sorted alphabetically",
	"artist_alpha_desc": "Sorted alphabetically",
	"music_record_count_asc": "Sorted by song count",
	"music_record_count_desc": "Sorted by song count",
	"playlist_alpha_asc": "Sorted alphabetically",
	"playlist_alpha_desc": "Sorted alphabetically",
	"album_artist_alpha_asc": "Sorted by Artist",
	"album_artist_alpha_desc": "Sorted by Artist"
}

# Song lists are either a TagLibTrackList (All Songs), sorted natively without
# making a record per track, or an Array of records (albums, artists,
# playlists). Titles compare ignoring case either way.
static func _sort_songs(music_records, key: String, descending: bool, less: Callable):
	if music_records is TagLibTrackList: music_records.sort_by(key, descending)
	else: music_records.sort_custom(less)

static func song_alpha_asc(music_records):
	_sort_songs(music_records, "title", false,
		func(a: TagLibMusicRecord, b: TagLibMusicRecord): return a.title.nocasecmp_to(b.title) < 0)

static func song_alpha_desc(music_records):
	_sort_songs(music_records, "title", true,
		func(a: TagLibMusicRecord, b: TagLibMusicRecord): return a.title.nocasecmp_to(b.title) > 0)

static func song_track_asc(music_records):
	_sort_songs(music_records, "track", false, func(a: TagLibMusicRecord, b: TagLibMusicRecord):
		if a.disc != b.disc: return a.disc < b.disc
		return a.track < b.track)

static func song_track_desc(music_records):
	_sort_songs(music_records, "track", true, func(a: TagLibMusicRecord, b: TagLibMusicRecord):
		if a.disc != b.disc: return a.disc > b.disc
		return a.track > b.track)
	
static func album_alpha_asc(albums):
	albums.sort_custom(func(a: TagLibAlbumRecord, b: TagLibAlbumRecord): return a.name < b.name)

static func album_alpha_desc(albums):
	albums.sort_custom(func(a: TagLibAlbumRecord, b: TagLibAlbumRecord): return a.name > b.name)	

static func artist_alpha_asc(artists):
	artists.sort_custom(func(a: TagLibArtistRecord, b: TagLibArtistRecord): return a.name < b.name)

static func artist_alpha_desc(artists):
	artists.sort_custom(func(a: TagLibArtistRecord, b: TagLibArtistRecord): return a.name > b.name)	

# Albums / artists know their size without building their record Array.
static func _record_count(item) -> int:
	if item is TagLibTrackGroup: return item.track_count
	return item.music_records.size()

static func music_record_count_asc(collection):
	collection.sort_custom(func(a, b): return _record_count(a) < _record_count(b))

static func music_record_count_desc(collection):
	collection.sort_custom(func(a, b): return _record_count(a) > _record_count(b))

static func playlist_alpha_asc(playlists):
	playlists.sort_custom(func(a: M3uCollection, b: M3uCollection): return a.name < b.name)

static func playlist_alpha_desc(playlists):
	playlists.sort_custom(func(a: M3uCollection, b: M3uCollection): return a.name > b.name)	

static func album_artist_alpha_asc(collection):
	collection.sort_custom(func(a, b): return a.album_artist < b.album_artist)

static func album_artist_alpha_desc(collection):
	collection.sort_custom(func(a, b): return a.album_artist > b.album_artist)
