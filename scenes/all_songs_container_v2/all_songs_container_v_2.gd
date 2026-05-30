extends BoxContainer

class_name AllSongsContainerV2

var songo_data = SongoDataResource.get_instance()
var music_records
var list_items = []
var collection
var album
var artist
var playlist

var override_return_focus: bool = false

var virtualized_list
var bar_scrolling = false
var sort_options
var sort_index = 0
var focused_song:
	get: return get_focused_song()
	
	
func _ready():
	if ThemeManager.current_theme.has("collection_options"):
		var options = ThemeManager.current_theme["collection_options"]
		%VirtualizedListContainer.add_theme_constant_override("margin_left", options["list_container_margin_left"])
		%VirtualizedListContainer.add_theme_constant_override("margin_right", options["list_container_margin_right"])
		%VirtualizedListContainer.add_theme_constant_override("margin_top", options["list_top_fade"])
		%VirtualizedListContainer.add_theme_constant_override("margin_bottom", options["list_bottom_fade"])
		
		if options.has("vertical_layout"): vertical = options["vertical_layout"]
			
func get_focused_song():
	return %VirtualizedList.focused_item

func setup_collection(collection_arg):
	collection = collection_arg
	if "music_records" in collection:
		list_items = collection.music_records
	else:
		list_items = collection
	sort_options = CollectionHelper.sort_options
	Callable(SongoSort, sort_options[sort_index]).call(list_items)
	$ThemeCollectionHeader.setup(sort_options[sort_index])

	await %VirtualizedList.ready
	virtualized_list = %VirtualizedList
	virtualized_list.setup(list_items, "res://scenes/all_songs_container_v2/song_button_v2.tscn")
	if "SONGS" in CollectionHelper.collection_type:
		%ShuffleButtonMarginContainer.show()
		%ShuffleButton.grab_focus()
	else:
		virtualized_list.focus_first()
	virtualized_list.scroll_vertical = 0
	var scroll_bar = virtualized_list.get_v_scroll_bar()
	scroll_bar.focus_entered.connect(func(): bar_scrolling = true )

func _on_item_removed(music_record):
	$CollectionHeader.record_count = music_records.size()
	%VirtualizedList.remove_focused_item()
	if Controller.active_container is ThemeMainSongView:
		Controller.skip_refocus = true

	
func render_ui():
	if playlist:
		%PlaylistGuide.visible = music_records.size() == 0


func handle_input(delta: float):	
	if Input.is_action_just_pressed("back"):
		Controller.new_nav_back()
	if Input.is_action_just_pressed("x"):
		kick_off_shuffle()
	if Input.is_action_just_pressed("ui_left"):
		if bar_scrolling:
			bar_scrolling = false;
		else:
			if list_items.size() == 0:
				UiHelper.flash_message("... what exactly are you trying to sort?")
				return
				
			if list_items.size() == 1:
				UiHelper.flash_message("... there's only one here. Sorting anyways")
	
			sort_index = (sort_index+1) % sort_options.size()
			var sort_key = sort_options[sort_index]
			Callable(SongoSort, sort_key).call(list_items)
			virtualized_list.scroll_vertical = 0
			virtualized_list.data_items = list_items
			virtualized_list.update_visible_items()
			default_focus()
			$ThemeCollectionHeader.setup(sort_options[sort_index])
	
func kick_off_shuffle():
	if list_items.size() == 0: return
	Controller.songs_panel(list_items, 0, SongoPlayerV2.MODE.SHUFFLE)

func truncate_with_ellipsis(text: String, limit: int) -> String:
	if text.length() <= limit:
		return text
	return text.substr(0, limit) + "…"
	
func _on_shuffle_button_pressed() -> void:
	kick_off_shuffle()

func default_focus():
	if "SONGS" in CollectionHelper.collection_type:
		%ShuffleButtonMarginContainer.show()
		%ShuffleButton.grab_focus()
	else:
		virtualized_list.focus_first()

	
func _on_tree_entered() -> void:
	if Controller.skip_refocus:
		await get_tree().process_frame
		call_deferred("default_focus")
		
func _on_shuffle_button_mouse_entered() -> void:
	%ShuffleButton.grab_focus()
	

func _on_shuffle_button_focus_entered() -> void:
	var focus_color: Color = %ShuffleButton.get_theme_color("font_focus_color")
	for mod_node in [%ShuffleIcon, %ShuffleText1, %ShuffleText2]:
		mod_node.modulate = focus_color

func _on_shuffle_button_focus_exited() -> void:
	for mod_node in [%ShuffleIcon, %ShuffleText1, %ShuffleText2]:
		mod_node.modulate = Color.WHITE
