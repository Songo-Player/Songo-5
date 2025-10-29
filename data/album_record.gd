class_name AlbumRecord extends Resource

@export var name: String
#@export var song_cover_path: ImageTexture
@export var cover_path: String
@export var artists: Array[String]
@export var music_records: Array[MusicRecord]

var cover:
	get: 
		var image = Image.new()
		image.load(cover_path)
		return image
