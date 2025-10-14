extends VBoxContainer

class_name AlbumsContainer

signal closing_container
signal opening_album(album_name)

var songo_data = SongoDataResource.get_instance()
var songo_player
var albums
	
func setup(songo_player_arg: SongoPlayer):
	songo_player = songo_player_arg
	albums = songo_data.albums
	build_list()
	
func render_ui():
	pass
	
func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		closing_container.emit()
		
func build_list():
	var batch_size = 5
	for i in albums.size():
		var button = load("res://scenes/albums_container/album_button.tscn").instantiate()
		%AlbumContainer.add_child(button)
		button.setup(albums[i])
		button.get_child(0).pressed.connect(func(): _on_open_album(albums[i].name))
		if i % batch_size == 0:
			%AlbumCount.text = "%d Total" % (i+1)
			await Engine.get_main_loop().process_frame
		if i == 0:
			call_deferred("focus_first_album")
		
	%AlbumCount.text = "%d Total" % songo_data.album_count
	
	
func focus_first_album():
	var first_child = %AlbumContainer.get_child(0)
	if first_child: first_child.get_child(0).grab_focus()
	%ScrollContainer.scroll_vertical = 0
	
func _on_open_album(album_name):
	opening_album.emit(album_name)
