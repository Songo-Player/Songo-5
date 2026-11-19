@tool
extends RefCounted
## What gets jotted on the main menu's sticky note for each menu entry: a few
## casual notes about the library, the button's wording, and what photo to
## pin up. Library totals are worked out once and kept, since walking every
## song creates a record object for each one.

static var _stats := {}

## Notes for the menu entry with this label:
## { lines: [String], button: String, photo: { kind, record } }
## where photo.kind is "song", "album", "artist", "playlist" or "" (the
## default photo).
static func for_entry(label: String) -> Dictionary:
	var s := _library_stats()
	match label:
		"All Songs":
			var lines := [
				"- %s of music :)" % _hours(s.seconds),
				"- %d song%s across %d album%s" % [s.songs, _plural(s.songs), s.albums, _plural(s.albums)],
			]
			if s.favorite != null:
				lines.append("- my favorite song is ... %s" % s.favorite.title)
			else:
				lines.append("- haven't played anything yet!")
			return {"lines": lines, "button": "view songs", "photo": {"kind": "song", "record": s.favorite}}
		"Albums":
			var lines := ["- %d album%s on the shelf" % [s.albums, _plural(s.albums)]]
			if s.biggest_album != null:
				lines.append("- biggest is %s" % s.biggest_album.name)
				lines.append("  (%d songs!)" % s.biggest_album.music_records.size())
			return {"lines": lines, "button": "view albums", "photo": {"kind": "album", "record": s.random_album}}
		"Artists":
			var lines := ["- %d artist%s" % [s.artists, _plural(s.artists)]]
			if s.top_artist != null:
				lines.append("- most songs: %s" % s.top_artist.name)
				lines.append("  (%d of them)" % s.top_artist.music_records.size())
			return {"lines": lines, "button": "view artists", "photo": {"kind": "artist", "record": s.top_artist}}
		"Playlists":
			if s.playlists == 0:
				return {"lines": ["- no playlists yet...", "- make one! ->"], "button": "view playlists",
					"photo": {"kind": "", "record": null}}
			var lines := ["- %d playlist%s" % [s.playlists, _plural(s.playlists)]]
			if s.longest_playlist != null:
				lines.append("- longest: %s" % s.longest_playlist.name)
			return {"lines": lines, "button": "view playlists", "photo": {"kind": "playlist", "record": s.longest_playlist}}
		"Settings":
			return {"lines": ["- themes, controls, sound", "- library + storage stuff", "- don't break anything ;)"],
				"button": "open settings", "photo": {"kind": "", "record": null}}
		"Exit":
			return {"lines": ["- class dismissed!", "- see you next time"], "button": "leave :(",
				"photo": {"kind": "", "record": null}}
	return {"lines": ["- something new to check out"], "button": "open", "photo": {"kind": "", "record": null}}

## Forgets the totals, e.g. after a library import.
static func forget() -> void:
	_stats = {}

static func _library_stats() -> Dictionary:
	if not _stats.is_empty(): return _stats
	var stats := {
		"songs": 0, "seconds": 0.0, "albums": 0, "artists": 0, "playlists": 0, "favorite": null,
		"biggest_album": null, "random_album": null, "top_artist": null, "longest_playlist": null,
	}
	if Engine.is_editor_hint():
		return stats
	var data := SongoDataResource.get_instance()
	var songs = data.music_records
	stats.songs = songs.size()
	var most_listens := 0
	for i in songs.size():
		var record = songs[i]
		stats.seconds += maxf(float(record.raw_length), 0.0)
		if record.listen_count > most_listens:
			most_listens = record.listen_count
			stats.favorite = record
	stats.albums = data.albums.size()
	stats.artists = data.artists.size()
	stats.playlists = data.playlists.size()
	stats.biggest_album = _largest(data.albums)
	stats.top_artist = _largest(data.artists)
	stats.longest_playlist = _largest(data.playlists)
	if not data.albums.is_empty():
		stats.random_album = data.albums[randi() % data.albums.size()]
	_stats = stats
	return stats

static func _largest(collections: Array):
	var best = null
	for collection in collections:
		if best == null or collection.music_records.size() > best.music_records.size():
			best = collection
	return best

static func _hours(seconds: float) -> String:
	var hours := seconds / 3600.0
	if hours < 1.0:
		return "about %d minutes" % maxi(1, int(roundf(seconds / 60.0)))
	var whole := int(hours)
	var rest := hours - whole
	if rest < 0.15: return "about %d hour%s" % [whole, _plural(whole)]
	if rest > 0.85: return "almost %d hours" % (whole + 1)
	return "a bit over %d hour%s" % [whole, _plural(whole)]

static func _plural(count: int) -> String:
	return "" if count == 1 else "s"
