extends MarginContainer

var songo_data = SongoDataResource.get_instance()
var songo_settings = SongoSettings.get_instance()

var showing: bool = false


func _info_panel_visible() -> bool:
	return UiHelper.info_panel != null and UiHelper.info_panel.visible


func _process(delta: float) -> void:
	if _info_panel_visible():
		return

	if Input.is_action_pressed("Y"):
		showing = true
		update_quick_menu_vals()
	else:
		showing = false

	visible = showing


func _input(event: InputEvent) -> void:
	if showing && not _info_panel_visible():
		for action_event in InputMap.action_get_events("ui_up"):
			if event.is_match(action_event) and event.is_pressed():
				handle_playlist_quick_edit()
				break  # Stop after finding a match

		for action_event in InputMap.action_get_events("ui_down"):
			if event.is_match(action_event) and event.is_pressed():
				handle_queue_music()
				break  # Stop after finding a match

		for action_event in InputMap.action_get_events("ui_left"):
			if event.is_match(action_event) and event.is_pressed():
				if Controller.nav_label.size() == 1:
					songo_settings.rotate_display = not songo_settings.rotate_display
					songo_settings.save()
					UiHelper.apply_rotation()
				else:
					change_target_playlist(-1)
				break  # Stop after finding a match

		for action_event in InputMap.action_get_events("ui_right"):
			if event.is_match(action_event) and event.is_pressed():
				if Controller.nav_label.size() != 1:
					change_target_playlist(1)
				break  # Stop after finding a match

	if showing:
		get_viewport().set_input_as_handled()


func change_target_playlist(direction: int) -> void:
	if songo_data.playlists.size() == 0: return
	if songo_data.playlists.size() == 1: UiHelper.flash_message("Only one playlist to use")
	songo_data.target_playlist_index = wrapi(songo_data.target_playlist_index + direction, 0, songo_data.playlists.size())
	songo_data.save()

func handle_queue_music():
	if "music_records" in Controller.active_container && SongoPlayerV2.is_playing():
		var queue_song = Controller.active_container.focused_song
		SongoPlayerV2.queue_music(queue_song)
		UiHelper.flash_message("Queued %s" % queue_song.title)

func get_playlist_target_song():
	var target = CollectionHelper.target_item
	if target && target is TagLibMusicRecord:
		return target

	if Controller.active_container is ThemeMainSongView:
		return SongoPlayerV2.get_current_music_record()
	return null

func get_playlist_target_collection():
	if songo_data.target_playlist == null: return null
	var target = CollectionHelper.target_item
	if target is M3uCollection:
		return null
	if target is SettingRecord:
		return null
	if target && target is not TagLibMusicRecord:
		return target
	else: return null

func update_quick_menu_vals():
	if songo_data.playlists.size() != 0:
		%PlaylistSwitchContainer.visible = Controller.nav_label.size() != 1
		%TargetPlaylistLabel.text = songo_data.target_playlist.name
	else:
		%PlaylistSwitchContainer.hide()

	var actions_available = false
	var target_song = get_playlist_target_song()
	if target_song && songo_data.target_playlist:
		actions_available = true
		%AddRemoveInPlaylistQuick.show()
		var new_text = ""
		if target_song in songo_data.target_playlist.music_records:
			new_text = "Remove song from playlist"
		else:
			new_text = "Add song to playlist"
		%AddRemoveInPlaylistLabel.text = new_text

	var target_collection = get_playlist_target_collection()
	if target_collection && songo_data.target_playlist:
		actions_available = true
		var overlap = songo_data.target_playlist.get_collection_overlap(target_collection.music_records)
		%AddRemoveInPlaylistQuick.show()
		var collection_type = "album"
		if target_collection is TagLibArtistRecord:
			collection_type = "artist"

		var new_text = ""
		if overlap >= 0.5:
			new_text = ": Remove %s from playlist" % [collection_type]
		else:
			new_text = ": Add %s to playlist" % [collection_type]
		%AddRemoveInPlaylistLabel.text = new_text

	if (target_collection == null && target_song == null) || songo_data.target_playlist == null:
		%AddRemoveInPlaylistQuick.hide()

	if Controller.active_container is AllSongsContainerV2 && target_song && SongoPlayerV2.is_playing():
		actions_available = true
		%QueueSong.show()
	else:
		%QueueSong.hide()

	if Controller.nav_label.size() == 1:
		%RotateDisplay.show()
		actions_available = true
	else:
		%RotateDisplay.hide()
	%NoQuickMenuActions.visible = not actions_available

func handle_playlist_quick_edit():
	var target_collection = get_playlist_target_collection()
	if target_collection && songo_data.target_playlist:
		var overlap = songo_data.target_playlist.get_collection_overlap(target_collection.music_records)
		var handled_song_count = 0
		if overlap >= 0.5:
			handled_song_count = songo_data.target_playlist.remove_tracks(target_collection.music_records)
			UiHelper.flash_message("%d songs removed from %s" % [handled_song_count, songo_data.target_playlist.name])
		else:
			handled_song_count = songo_data.target_playlist.add_tracks(target_collection.music_records)
			UiHelper.flash_message("%d songs added to %s" % [handled_song_count, songo_data.target_playlist.name])

	var target_song = get_playlist_target_song()
	if target_song && songo_data.target_playlist:
		if target_song in songo_data.target_playlist.music_records:
			songo_data.target_playlist.remove_track(target_song.full_path)
			UiHelper.flash_message("Song removed from %s" % songo_data.target_playlist.name)
		else:
			songo_data.target_playlist.add_track(target_song.full_path)
			UiHelper.flash_message("Song added to %s" % songo_data.target_playlist.name)
