extends VBoxContainer

class_name ArtistsContainer

var artists
	
var focused_collection:
	get: return get_focused_collection()
	
func get_focused_collection():
	if %VirtualizedList.focused_item == null: return artists[0]
	return %VirtualizedList.focused_item
	
func setup(artists_arg: Array[ArtistRecord]):
	artists = artists_arg
	await %VirtualizedList.ready
	%VirtualizedList.visible_item_count = 8
	%VirtualizedList.setup(artists, "res://scenes/artists_container/artist_button.tscn")
	%ArtistCount.text = "%d Total" % artists.size()
	
func render_ui():
	pass
	
func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.new_nav_back()
