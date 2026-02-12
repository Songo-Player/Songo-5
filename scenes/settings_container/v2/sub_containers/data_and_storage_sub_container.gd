extends MarginContainer

var songo_data = SongoDataResource.get_instance()
var songo_settings = SongoSettings.get_instance()

func setup():
	build_music_dirs_list()
	update_auto_import_ui()
	
func _ready():
	await get_tree().process_frame
	%PageLabel.grab_focus()
	%ScrollContainer.scroll_vertical = 0
	
func render_ui():
	%DefaultMusicDirsLabel.visible = songo_data.music_directory_paths.size() == 0
	
func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.new_nav_back()


func build_music_dirs_list():	
	for i in range(songo_data.music_directory_paths.size()):
		var new_item = load("res://scenes/settings_container/directory_path_item.tscn").instantiate()
		var path = songo_data.music_directory_paths[i]
		new_item.setup(path)
		%CurrentMusicDirectories.add_child(new_item)
		new_item.removed_dir.connect(func(): 
			UiHelper.focus_back()
			new_item.queue_free()
		)

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
	if songo_data.importing == true:
		UiHelper.app_message.show_message("An Import is currently in progress.")
	else:
		Controller.settings_directory_select()

func _on_reimport_dirs_button_pressed() -> void:
	if songo_data.importing == true:
		UiHelper.app_message.show_message("An Import is currently in progress.")
	else:
		songo_data.index_mp3s()

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
		if artist.set_dicebear_image():
			update_count += 1
	UiHelper.flash_message("Artist images rebuilt (%d images added)" % update_count)

func _on_delete_playlist_images_button_pressed() -> void:
	var playlist_images_dir = "user://playlist_images/"
	var dir_access = DirAccess.open(playlist_images_dir)
	if dir_access:
		var files = dir_access.get_files_at(playlist_images_dir)
		for file_name in files:
			if !file_name.contains("-override"):
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
