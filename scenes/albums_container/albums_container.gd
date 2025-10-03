extends VBoxContainer

class_name AlbumsContainer

signal closing_container
#signal opening_song_panel(play_type)

var songo_data = SongoDataResource.get_instance()
var songo_player
#var mp3_records
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
	for i in albums.size():
		var button = load("res://scenes/albums_container/album_button.tscn").instantiate()
		#button.text = albums[i].name
		print(albums[i].cover)
		%AlbumContainer.add_child(button)
		button.setup(albums[i])
		%AlbumCount.text = "%d Total" % (i+1)
		await Engine.get_main_loop().process_frame
		
		#button.pressed.connect(func(): print(albums[i].name))
	%AlbumCount.text = "%d Total" % songo_data.album_count
	call_deferred("focus_first_album")
	
#func play_song(play_index: int):
#	songo_player.play_index = play_index
#	opening_song_panel.emit("Playing")
	
func focus_first_album():
	var first_child = %AlbumContainer.get_child(0)
	if first_child: first_child.get_child(0).grab_focus()
	%ScrollContainer.scroll_vertical = 0
