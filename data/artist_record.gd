class_name ArtistRecord extends Resource

@export var name: String = "Unknown Artist"
@export var img_path: String = ""
@export var music_records: Array[MusicRecord]

var artist_image:
	get: 
		var image = Image.new()
		image.load(img_path)
		return image
		
static func merge_artists(existing_artists: Array[ArtistRecord], new_artists: Array[ArtistRecord]) -> Array[ArtistRecord]:
	var artist_map := {}

	for artist in existing_artists:
		artist_map[artist.name] = artist

	for new_artist in new_artists:
		if artist_map.has(new_artist.name):
			var existing_artist = artist_map[new_artist.name]
			for record in new_artist.music_records:
				if record not in existing_artist.music_records:
					existing_artist.music_records.append(record)	
		else:
			artist_map[new_artist.name] = new_artist
	var result: Array[ArtistRecord]	
	result.assign(artist_map.values())
	return result
