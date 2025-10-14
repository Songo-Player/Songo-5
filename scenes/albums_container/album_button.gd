extends PanelContainer

var album_record: AlbumRecord

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	
func setup(album_record_arg):
	album_record = album_record_arg
	#print(OS.get_user_data_dir())
	if album_record.cover_path != "":
		%AlbumCover.texture = ImageTexture.create_from_image(album_record.cover)
		%FallbackCover.hide()
	else:
		%AlbumCover.hide()
	%AlbumName.text = album_record.name
	%ArtistName.text = album_record.artist

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
