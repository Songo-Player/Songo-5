class_name AlbumRecord extends Resource

@export var name: String
#@export var song_cover_path: ImageTexture
@export var cover_path: String
@export var artist: String

var cover:
	get: 
		var image = Image.new()
		image.load(cover_path)
		print(cover_path)
		return image
