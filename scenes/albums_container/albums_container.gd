extends VBoxContainer

class_name AlbumsContainer

var albums
var bar_scrolling = false
var sort_index = 0
var sort_options = ["album_alpha_asc", "album_alpha_desc"]

var focused_collection:
	get: return get_focused_collection()
	
func get_focused_collection():
	if %VirtualizedList.focused_item == null: return albums[0]
	return %VirtualizedList.focused_item
	
func setup(albums_arg: Array[AlbumRecord]):
	albums = albums_arg.duplicate()
	await %VirtualizedList.ready
	%VirtualizedList.setup(albums, "res://scenes/albums_container/album_button.tscn")
	$CollectionHeader.collection_label = "Albums"
	$CollectionHeader.record_count = albums.size()
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
			Callable(SongoSort, sort_key).call(albums)
			%VirtualizedList.data_items = albums
			%VirtualizedList.update_visible_items()
			$CollectionHeader.fade_sort_label(sort_key)
			%VirtualizedList.scroll_vertical = 0
			await get_tree().process_frame
			%VirtualizedList.focus_first()
