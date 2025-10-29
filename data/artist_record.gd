class_name ArtistRecord extends Resource

@export var name: String = "Unknown Artist"
@export var img_path: String = ""
@export var music_records: Array[MusicRecord]

var artist_image:
	get: 
		var image = Image.new()
		image.load(img_path)
		return image
