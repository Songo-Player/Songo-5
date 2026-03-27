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
