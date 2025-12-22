class_name AlbumRecord extends Resource

@export var name: String
@export var cover_path: String
@export var artists: Array[String]
@export var music_records: Array[MusicRecord]

var cover:
	get: 
		var image = Image.new()
		image.load(cover_path)
		return image
	
static func merge_albums(existing_albums: Array[AlbumRecord], new_albums: Array[AlbumRecord]) -> Array[AlbumRecord]:
	var album_map := {}

	for album in existing_albums:
		album_map[album.name] = album

	for new_album in new_albums:
		if album_map.has(new_album.name):
			var existing_album = album_map[new_album.name]

			for artist in new_album.artists:
				if artist not in existing_album.artists:
					existing_album.artists.append(artist)
			for record in new_album.music_records:
				if record not in existing_album.music_records:
					existing_album.music_records.append(record)
		else:
			album_map[new_album.name] = new_album
			
	var result: Array[AlbumRecord]
	result.assign(album_map.values())
	return result
