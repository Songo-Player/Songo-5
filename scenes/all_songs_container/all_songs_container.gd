extends VBoxContainer

class_name AllSongsContainer

var songo_data = SongoDataResource.get_instance()
var sfx_player
var music_records
var album
var artist
var playlist

var override_return_focus: bool = false

var virtualized_list
var focused_song:
	get: return get_focused_song()
	
func get_focused_song():
	return %VirtualizedList.focused_item

	
func setup(music_records_arg: Array[MusicRecord], sfx_player_arg):
	music_records = music_records_arg
	sfx_player = sfx_player_arg
	
	%SongsListLabel.text = "All Songs"
	%SongCount.text = "%d Total" % music_records.size()

	await %VirtualizedList.ready
	virtualized_list = %VirtualizedList
	virtualized_list.setup(music_records, "res://scenes/all_songs_container/song_button.tscn")
	%ShuffleButton.grab_focus()
	virtualized_list.scroll_vertical = 0

func set_as_album(album_arg):
	album = album_arg
	%CustomSongListImage.show()
	%SongsListLabel.text = album.name
	var image = album.cover
	if image: %CustomSongListImage.texture = ImageTexture.create_from_image(image)

func set_as_playlist(playlist_arg):
	playlist = playlist_arg
	%CustomSongListImage.show()
	%SongsListLabel.text = playlist.name
	var image = playlist.img
	if image: %CustomSongListImage.texture = ImageTexture.create_from_image(image)
	playlist.item_removed.connect(_on_item_removed)

func _on_item_removed(music_record):
	%SongCount.text = "%d Total" % music_records.size()
	%VirtualizedList.remove_focused_item()
	if Controller.active_container is SongPanelContainer:
		Controller.skip_refocus = true
	
func set_as_artist(artist_arg):
	artist = artist_arg
	%CustomSongListImage.show()
	%SongsListLabel.text = artist.name
	var image = artist.artist_image
	if image: %CustomSongListImage.texture = ImageTexture.create_from_image(image)

func render_ui():
	if playlist:
		%PlaylistGuide.visible = music_records.size() == 0


func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.new_nav_back()
	
	if Input.is_action_pressed("x"):
		kick_off_shuffle()
		
	if Input.is_action_just_pressed("ui_accept"):
		var focused_button = get_viewport().gui_get_focus_owner()
		if focused_button.has_meta("item_index"):
			var target_index = focused_button.get_meta("item_index")
			#%VirtualizedList.remove_data_item(music_records[target_index])
			Controller.songs_panel(music_records, target_index, "Playing")
		
func kick_off_shuffle():
	if music_records.size() == 0: return
	var shuffled_music = music_records.duplicate()
	shuffled_music.shuffle()
	Controller.songs_panel(shuffled_music, 0, "Shuffle Play")

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
		
