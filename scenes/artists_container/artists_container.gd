extends VBoxContainer

class_name ArtistsContainer

var artists
var bar_scrolling = false
var sort_index = 0
var sort_options = ["artist_alpha_asc", "artist_alpha_desc", "music_record_count_asc", "music_record_count_desc"]
	
var focused_collection:
	get: return get_focused_collection()
	
func get_focused_collection():
	if %VirtualizedList.focused_item == null: return artists[0]
	return %VirtualizedList.focused_item
	
func setup(artists_arg: Array[ArtistRecord]):
	artists = artists_arg.duplicate()
	SongoSort.artist_alpha_asc(artists)
	await %VirtualizedList.ready
	%VirtualizedList.visible_item_count = 8
	%VirtualizedList.setup(artists, "res://scenes/artists_container/artist_button.tscn")
	#%ArtistCount.text = "%d Total" % artists.size()
	$CollectionHeader.collection_label = "Artists"
	$CollectionHeader.record_count = artists.size()
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
			Callable(SongoSort, sort_key).call(artists)
			%VirtualizedList.data_items = artists
			%VirtualizedList.update_visible_items()
			$CollectionHeader.fade_sort_label(sort_key)
			%VirtualizedList.scroll_vertical = 0
			await get_tree().process_frame
			%VirtualizedList.focus_first()
