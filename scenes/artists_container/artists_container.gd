extends VBoxContainer

class_name ArtistsContainer

var artists
	
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
		Controller.nav_back()
		
	if Input.is_action_just_pressed("ui_accept"):
		var focused_button = get_viewport().gui_get_focus_owner()
		var target_artist = artists[focused_button.get_meta("artist_index")]
		Controller.artist_songs_index(target_artist)
