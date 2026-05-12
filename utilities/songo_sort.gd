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

static func song_alpha_asc(music_records):
	music_records.sort_custom(func(a: MusicRecord, b: MusicRecord): return a.title < b.title)

static func song_alpha_desc(music_records):
	music_records.sort_custom(func(a: MusicRecord, b: MusicRecord): return a.title > b.title)

static func song_track_asc(music_records):
	music_records.sort_custom(func(a: MusicRecord, b: MusicRecord): return a.track < b.track)

static func song_track_desc(music_records):
	music_records.sort_custom(func(a: MusicRecord, b: MusicRecord): return a.track > b.track)
	
static func album_alpha_asc(albums):
	albums.sort_custom(func(a: AlbumRecord, b: AlbumRecord): return a.name < b.name)

static func album_alpha_desc(albums):
	albums.sort_custom(func(a: AlbumRecord, b: AlbumRecord): return a.name > b.name)	

static func artist_alpha_asc(artists):
	artists.sort_custom(func(a: ArtistRecord, b: ArtistRecord): return a.name < b.name)

static func artist_alpha_desc(artists):
	artists.sort_custom(func(a: ArtistRecord, b: ArtistRecord): return a.name > b.name)	

static func music_record_count_asc(collection):
	collection.sort_custom(func(a, b): return a.music_records.size() < b.music_records.size())

static func music_record_count_desc(collection):
	collection.sort_custom(func(a, b): return a.music_records.size() > b.music_records.size())

static func playlist_alpha_asc(playlists):
	playlists.sort_custom(func(a: M3uCollection, b: M3uCollection): return a.name < b.name)

static func playlist_alpha_desc(playlists):
	playlists.sort_custom(func(a: M3uCollection, b: M3uCollection): return a.name > b.name)	

static func album_artist_alpha_asc(collection):
	collection.sort_custom(func(a, b): return a.artists[0] < b.artists[0])

static func album_artist_alpha_desc(collection):
	collection.sort_custom(func(a, b): return a.artists[0] > b.artists[0])
