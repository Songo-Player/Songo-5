extends VBoxContainer

class_name PlaylistsContainer

var playlists
	
func setup(playlists_arg: Array[M3uCollection]):
	playlists = playlists_arg
	await %VirtualizedList.ready
	%VirtualizedList.visible_item_count = 8
	%VirtualizedList.setup(playlists, "res://scenes/playlists_container/playlist_button.tscn")
	
	
func render_ui():
	pass
	
func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.new_nav_back()


func _on_tree_entered() -> void:
	%PlaylistCount.text = "%d Total" % playlists.size()
