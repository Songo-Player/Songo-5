extends Node
class_name SongoSort

const TYPES = {
	"song_alpha_asc": "Sorted alphabetically (Asc)",
	"song_alpha_desc": "Sorted alphabetically (Desc)",
	"song_track_asc": "Sorted by track number (Asc)",
	"song_track_desc": "Sorted by track number (Desc)",
	"album_alpha_asc": "Sorted alphabetically (Asc)",
	"album_alpha_desc": "Sorted alphabetically (Desc)",
	"artist_alpha_asc": "Sorted alphabetically (Asc)",
	"artist_alpha_desc": "Sorted alphabetically (Desc)",
	"music_record_count_asc": "Sorted by song count (Asc)",
	"music_record_count_desc": "Sorted by song count (Desc)",
	"playlist_alpha_asc": "Sorted alphabetically (Asc)",
	"playlist_alpha_desc": "Sorted alphabetically (Desc)"
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
