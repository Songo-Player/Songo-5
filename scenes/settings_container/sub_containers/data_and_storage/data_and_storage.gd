extends MarginContainer

var songo_data = SongoDataResource.get_instance()
var songo_settings = SongoSettings.get_instance()

const DIRECTORY_PATH_ITEM_PATH = "res://scenes/settings_container/sub_containers/data_and_storage/directory_path_item/directory_path_item.tscn"
const PLAYLIST_ITEM_PATH = "res://scenes/settings_container/sub_containers/data_and_storage/playlist_item/playlist_item.tscn"

func setup():
	build_music_dirs_list()
	build_playlists_list()
	update_auto_import_ui()
	
func _ready():
	await get_tree().process_frame
	%PageLabel.grab_focus()
	%ScrollContainer.scroll_vertical = 0
	
func render_ui():
	%DefaultMusicDirsLabel.visible = songo_data.music_directory_paths.size() == 0
	
func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.nav_back()


func build_music_dirs_list():	
	for i in range(songo_data.music_directory_paths.size()):
		var new_item = load(DIRECTORY_PATH_ITEM_PATH).instantiate()
		var path = songo_data.music_directory_paths[i]
		new_item.setup(path)
		%CurrentMusicDirectories.add_child(new_item)
		new_item.removed_dir.connect(func(): 
			%AddNewDirButton.grab_focus()
			new_item.queue_free()
		)

func build_playlists_list():
	for child in %CurrentPlaylists.get_children():
		%CurrentPlaylists.remove_child(child)
		child.queue_free()
		
	for playlist in songo_data.playlists:
		var new_item = load(PLAYLIST_ITEM_PATH).instantiate()
		new_item.setup(playlist)
		%CurrentPlaylists.add_child(new_item)
		new_item.removed_playlist.connect(func(): 
			%NewPlaylistButton.grab_focus()
			build_playlists_list()
		)
	if songo_data.playlists.size() == 0: %DefaultPlaylistsLabel.show()
	else: %DefaultPlaylistsLabel.hide()

func update_auto_import_ui():
	var status = songo_settings.auto_import
	if status:
		%AutoImportEnabled.show()
		%AutoImportDisabled.hide()
		%AutoImportToggleButton.text = "Disable"
	else:
		%AutoImportEnabled.hide()
		%AutoImportDisabled.show()
		%AutoImportToggleButton.text = "Enable"
		
func _on_tree_entered() -> void:
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

func _on_tree_exiting() -> void:
	get_viewport().gui_focus_changed.disconnect(_on_focus_changed)

func _on_focus_changed(item: Control):
	if item == %RebuildPlaylistImagesButton || item == %DeletePlaylistImagesButton:
		%ScrollContainer.scroll_vertical = 999

func _on_add_new_dir_button_pressed() -> void:
	if songo_data.importing:
		UiHelper.app_message.show_message("An Import is currently in progress.")
		return

	if OS.get_name() != "Android":
		Controller.settings_directory_select()
		return

	if has_all_files_access():
		Controller.settings_directory_select()
	else:
		# Routes the user to the "Allow access to manage all files"
		# system settings screen for your app.
		OS.request_permissions()


func has_all_files_access() -> bool:
	for p in OS.get_granted_permissions():
		if p.findn("MANAGE_EXTERNAL_STORAGE") != -1:
			return true
	return false

func _on_delete_generated_album_images_button_pressed() -> void:
	var album_images_dir = "user://album_images/"
	var dir_access = DirAccess.open(album_images_dir)
	if dir_access:
		var files = dir_access.get_files_at(album_images_dir)
		for file_name in files:
			if !file_name.contains("-override"):
				var file_path = album_images_dir + file_name
				var error = DirAccess.remove_absolute(file_path)
				if error != OK:
					print("Failed to remove file %s: %s" % [file_path, error])
	else:
		print("An error occurred when trying to access the path.")
	
	UiHelper.flash_message("Album images deleted.")

func _on_delete_artist_image_data_button_pressed() -> void:
	var artist_images_dir = "user://artist_images/"
	var dir_access = DirAccess.open(artist_images_dir)
	if dir_access:
		var files = dir_access.get_files_at(artist_images_dir)
		for file_name in files:
			if !file_name.contains("-override"):
				var file_path = artist_images_dir + file_name
				var error = DirAccess.remove_absolute(file_path)
				if error != OK:
					print("Failed to remove file %s: %s" % [file_path, error])
	else:
		print("An error occurred when trying to access the path.")
	
	UiHelper.flash_message("Artist images deleted.")

func _on_delete_indexed_music_data_pressed() -> void:
	if songo_data.importing == true:
		UiHelper.app_message.show_message("An Import is currently in progress.")
	else:
		songo_data.clear_music_data()
		UiHelper.flash_message("Indexed Music Data deleted.")

func _on_auto_import_toggle_button_pressed() -> void:
	songo_settings.auto_import = not songo_settings.auto_import
	songo_settings.save()
	update_auto_import_ui()


func _on_rebuild_artist_image_data_button_pressed() -> void:
	var update_count = 0
	for artist in songo_data.artists:
		if Artwork.ensure_dicebear(artist.asset_id, "artist"):
			update_count += 1
	UiHelper.flash_message("Artist images rebuilt (%d images added)" % update_count)

func _on_delete_playlist_images_button_pressed() -> void:
	var playlist_images_dir = "user://playlist_images/"
	var dir_access = DirAccess.open(playlist_images_dir)
	if dir_access:
		var files = dir_access.get_files_at(playlist_images_dir)
		for file_name in files:
			var file_path = playlist_images_dir + file_name
			var error = DirAccess.remove_absolute(file_path)
			if error != OK:
				print("Failed to remove file %s: %s" % [file_path, error])
	else:
		print("An error occurred when trying to access the path.")
	
	UiHelper.flash_message("Playlist images deleted.")


func _on_rebuild_playlist_images_button_pressed() -> void:
	var update_count = 0
	for playlist in songo_data.playlists:
		if playlist.set_dicebear_image():
			update_count += 1
	UiHelper.flash_message("Playlist images rebuilt (%d images added)" % update_count)


func _on_rebuild_album_images_button_pressed() -> void:
	songo_data.rebuild_album_images()


func _on_rebuild_indexed_music_data_pressed() -> void:
	if songo_data.importing == true:
		UiHelper.app_message.show_message("An Import is currently in progress.")
		return

	songo_data.index_mp3s()
	await songo_data.import_finished

	if songo_data.import_notes.is_empty():
		UiHelper.flash_message("Indexed Music Data rebuilt (0 changes)")
		
func _on_new_playlist_button_pressed() -> void:
	var keyboard = UiHelper.keyboard
	# Still connected if the last keyboard was dismissed with back instead of
	# enter (the disconnect only happens once a result comes in).
	if not keyboard.keyboard_result.is_connected(_keyboard_playlist_entered):
		keyboard.keyboard_result.connect(_keyboard_playlist_entered)
	keyboard.setup("New Playlist Name")
	
func _keyboard_playlist_entered(new_playlist_name):
		var keyboard = UiHelper.keyboard
		keyboard.keyboard_result.disconnect(_keyboard_playlist_entered)
		
		if new_playlist_name.strip_edges() == "":
			UiHelper.flash_message("A playlist name can't be blank")
			return
		if new_playlist_name.strip_edges().to_lower() == "blank":
			UiHelper.flash_message("Haha very funny. Playlist name can't be empty")
			return
		if new_playlist_name.strip_edges().to_lower() == "empty":
			UiHelper.flash_message("Fine. You win. Call your playlist 'empty'. I hope you're happy")
			
		var new_playlist = M3uCollection.create_collection(new_playlist_name)
		if new_playlist:
			new_playlist.set_dicebear_image()
			songo_data.playlists.append(new_playlist)
			songo_data.target_playlist_index = songo_data.playlists.size() - 1
			songo_data.save()
			build_playlists_list()
		else:
			UiHelper.app_message.show_message("Something went wrong during playlist creation.")
