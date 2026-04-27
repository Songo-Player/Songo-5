extends VBoxContainer

class_name PlaylistsContainer

var playlists
var bar_scrolling = false
var sort_index = 0
var sort_options = ["playlist_alpha_asc", "playlist_alpha_desc", "music_record_count_asc", "music_record_count_desc"]
	
	
func setup(playlists_arg: Array[M3uCollection]):
	playlists = playlists_arg.duplicate()
	SongoSort.playlist_alpha_asc(playlists)
	await %VirtualizedList.ready
	%VirtualizedList.visible_item_count = 8
	%VirtualizedList.setup(playlists, "res://scenes/playlists_container/playlist_button.tscn")
	$CollectionHeader.collection_label = "Playlists"
	$CollectionHeader.record_count = playlists.size()
	$CollectionHeader.sort_label_key = sort_options[sort_index]
	var scroll_bar = %VirtualizedList.get_v_scroll_bar()
	scroll_bar.focus_entered.connect(func(): bar_scrolling = true )
	
	
func render_ui():
	pass
	
func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.new_nav_back()
	if Input.is_action_just_pressed("ui_left"):
		if bar_scrolling:
			bar_scrolling = false;
		else:
			sort_index = (sort_index+1) % sort_options.size()
			var sort_key = sort_options[sort_index]
			Callable(SongoSort, sort_key).call(playlists)
			%VirtualizedList.data_items = playlists
			%VirtualizedList.update_visible_items()
			$CollectionHeader.fade_sort_label(sort_key)
			%VirtualizedList.scroll_vertical = 0
			await get_tree().process_frame
			%VirtualizedList.focus_first()


func _on_tree_entered() -> void:
	$CollectionHeader.record_count = playlists.size()
