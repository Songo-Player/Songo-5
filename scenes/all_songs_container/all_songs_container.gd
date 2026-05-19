extends VBoxContainer

class_name AllSongsContainer

var songo_data = SongoDataResource.get_instance()
var music_records
var album
var artist
var playlist

var override_return_focus: bool = false

var virtualized_list
var bar_scrolling = false
var sort_options = ["song_alpha_asc", "song_alpha_desc"]
var sort_index = 0
var focused_song:
	get: return get_focused_song()
	
func get_focused_song():
	return %VirtualizedList.focused_item

	
func setup(music_records_arg: Array[MusicRecord]):
	music_records = music_records_arg.duplicate()

	$CollectionHeader.collection_label = "All Songs"
	$CollectionHeader.record_count = music_records.size()
	$CollectionHeader.sort_label_key = sort_options[sort_index]
	
	await %VirtualizedList.ready
	virtualized_list = %VirtualizedList
	virtualized_list.setup(music_records, "res://scenes/all_songs_container/song_button.tscn")
	%ShuffleButton.grab_focus()
	virtualized_list.scroll_vertical = 0
	var scroll_bar = virtualized_list.get_v_scroll_bar()
	scroll_bar.focus_entered.connect(func(): bar_scrolling = true )
	
func set_as_album(album_arg):
	album = album_arg
	$CollectionHeader.collection_label = album.name
	$CollectionHeader.default_type = CollectionHeader.DEFAULT_TYPE.ALBUM
	var image = album.cover
	if image: $CollectionHeader.custom_image_texture = ImageTexture.create_from_image(image)
	sort_options = ["song_track_asc", "song_track_desc", "song_alpha_asc", "song_alpha_desc"]
	Callable(SongoSort, "song_track_asc").call(music_records)
	$CollectionHeader.sort_label_key = sort_options[sort_index]
	
func set_as_playlist(playlist_arg):
	playlist = playlist_arg
	$CollectionHeader.collection_label = playlist.name
	$CollectionHeader.default_type = CollectionHeader.DEFAULT_TYPE.PLAYLIST
	var image = playlist.img
	if image: $CollectionHeader.custom_image_texture = ImageTexture.create_from_image(image)
	playlist.item_removed.connect(_on_item_removed)
	Callable(SongoSort, "song_alpha_asc").call(music_records)

func _on_item_removed(music_record):
	#%SongCount.text = "%d Total" % music_records.size()
	$CollectionHeader.record_count = music_records.size()
	%VirtualizedList.remove_focused_item()
	if Controller.active_container is ThemeMainSongView:
		Controller.skip_refocus = true
	
func set_as_artist(artist_arg):
	artist = artist_arg
	$CollectionHeader.collection_label = artist.name
	$CollectionHeader.default_type = CollectionHeader.DEFAULT_TYPE.ALBUM
	#%CustomSongListImage.show()
	#%SongsListLabel.text = artist.name
	var image = artist.artist_image
	#if image: %CustomSongListImage.texture = ImageTexture.create_from_image(image)
	if image: $CollectionHeader.custom_image_texture = ImageTexture.create_from_image(image)
	Callable(SongoSort, "song_alpha_asc").call(music_records)

	
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
			if music_records.size() == 0:
				UiHelper.flash_message("... what exactly are you trying to sort?")
				return
				
			sort_index = (sort_index+1) % sort_options.size()
			var sort_key = sort_options[sort_index]
			Callable(SongoSort, sort_key).call(music_records)
			virtualized_list.scroll_vertical = 0
			virtualized_list.data_items = music_records
			virtualized_list.update_visible_items()
			default_focus()
			$CollectionHeader.fade_sort_label(sort_key)
	
func kick_off_shuffle():
	if music_records.size() == 0: return
	Controller.songs_panel(music_records, 0, SongoPlayerV2.MODE.SHUFFLE)

func truncate_with_ellipsis(text: String, limit: int) -> String:
	if text.length() <= limit:
		return text
	return text.substr(0, limit) + "…"
	
func _on_shuffle_button_pressed() -> void:
	kick_off_shuffle()

func _on_top_bar_clip_mask_tree_entered() -> void:
	pass # Replace with function body.

func default_focus():
	%ShuffleButton.grab_focus()

	
func _on_tree_entered() -> void:
	if Controller.skip_refocus:
		await get_tree().process_frame
		call_deferred("default_focus")
		
func _on_shuffle_button_mouse_entered() -> void:
	%ShuffleButton.grab_focus()
	pass # Replace with function body.
	
