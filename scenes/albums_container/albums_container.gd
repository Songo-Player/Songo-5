extends VBoxContainer

class_name AlbumsContainer

var albums

var focused_collection:
	get: return get_focused_collection()
	
func get_focused_collection():
	if %VirtualizedList.focused_item == null: return albums[0]
	return %VirtualizedList.focused_item
	
func setup(albums_arg: Array[AlbumRecord]):
	albums = albums_arg
	await %VirtualizedList.ready
	%VirtualizedList.setup(albums, "res://scenes/albums_container/album_button.tscn")
	%AlbumCount.text = "%d Total" % albums.size()
	
func render_ui():
	pass
	
func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.new_nav_back()
		
	if Input.is_action_just_pressed("ui_accept"):
		var focused_button = get_viewport().gui_get_focus_owner()
		var target_album = albums[focused_button.get_meta("item_index")]
		Controller.album_songs_index(target_album)
