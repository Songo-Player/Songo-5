extends VBoxContainer

class_name SettingsContainer

var songo_data = SongoDataResource.get_instance()
var songo_settings = SongoSettings.get_instance()

var ui_scale = songo_settings.ui_scale
var theme_color = songo_settings.theme_color
var clock_24_hour = songo_settings.clock_24_hour
var main_menu_size = songo_settings.main_menu_size

func setup():
	%VersionLabel.text = SongoDataResource.VERSION
	%DeviceStrategyLabel.text = DeviceOS.device_strategy_name
	build_music_dirs_list()
	build_playlists_list()
	call_deferred("focus_first")
	call_deferred("update_theme_color_preview")
	update_auto_import_ui()
	update_clock_setting_ui()
	update_main_menu_size_ui()
	update_global_scale_ui()
	update_song_sleep_ui()
	#update_force_screen_fit_ui()
	update_song_following_ui()
	
func refocus():
	%ApplyUiButton.grab_focus()
	
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
		
func update_clock_setting_ui():
	if clock_24_hour:
		%Clock24HourEnabled.show()
		%Clock24HourDisabled.hide()
		%Clock24HourButton.text = "Disable"
	else:
		%Clock24HourEnabled.hide()
		%Clock24HourDisabled.show()
		%Clock24HourButton.text = "Enable"
		
#func update_force_screen_fit_ui():
#	if songo_settings.force_screen_fit:
#		%ForceScreenFitEnabled.show()
#		%ForceScreenFitDisabled.hide()
#		%ForceScreenFitButton.text = "Disable"
#	else:
#		%ForceScreenFitEnabled.hide()
#		%ForceScreenFitDisabled.show()
#		%ForceScreenFitButton.text = "Enable"
#
func update_song_following_ui():
	if songo_settings.song_following:
		%SongFollowingEnabled.show()
		%SongFollowingDisabled.hide()
		%SongFollowingButton.text = "Disable"
	else:
		%SongFollowingEnabled.hide()
		%SongFollowingDisabled.show()
		%SongFollowingButton.text = "Enable"
	

func update_main_menu_size_ui():
	var size_text = ["SM", "MD", "LG"][main_menu_size]
	%MainMenuSizeLabel.text = size_text
	
func update_global_scale_ui():
	%GlobalScaleDisplayLabel.text = "%.2fx" % ui_scale 

func update_song_sleep_ui():
	if songo_settings.song_sleep_timer == 0:
		%SongSleepTimerLabel.text = "NO"
	else:
		%SongSleepTimerLabel.text = "%ds" % songo_settings.song_sleep_timer
	
func focus_first():
	%AddNewDirButton.grab_focus()
	%ScrollContainer.scroll_vertical = 0
	
func render_ui():
	%DefaultMusicDirsLabel.visible = songo_data.music_directory_paths.size() == 0
	
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
		
func build_playlists_list():
	for child in %CurrentPlaylists.get_children():
		%CurrentPlaylists.remove_child(child)
		child.queue_free()
		
	for playlist in songo_data.playlists:
		var new_item = load("res://scenes/settings_container/playlist_item.tscn").instantiate()
		new_item.setup(playlist)
		%CurrentPlaylists.add_child(new_item)
		new_item.removed_playlist.connect(func(): 
			UiHelper.focus_back()
			build_playlists_list()
		)
	if songo_data.playlists.size() == 0:
		%DefaultPlaylistsLabel.show()
	else:
		%DefaultPlaylistsLabel.hide()

func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.new_nav_back()
		
	if Input.is_action_just_pressed("ui_accept"):
		pass

func update_theme_color_preview():
	%ThemeColorPreview.modulate = theme_color

func _on_add_new_dir_button_pressed() -> void:
	if songo_data.importing == true:
		UiHelper.app_message.show_message("An Import is currently in progress.")
	else:
		Controller.settings_directory_select()

func _on_delete_indexed_music_data_pressed() -> void:
	if songo_data.importing == true:
		UiHelper.app_message.show_message("An Import is currently in progress.")
	else:
		songo_data.clear_music_data()
		UiHelper.flash_message("Indexed Music Data deleted.")

func _on_reimport_dirs_button_pressed() -> void:
	if songo_data.importing == true:
		UiHelper.app_message.show_message("An Import is currently in progress.")
	else:
		songo_data.index_mp3s()
	
func _on_delete_scraped_artist_image_data_button_pressed() -> void:
	UiHelper.app_message.show_message("This isn't implemented yet")

func _on_delete_generated_album_images_button_pressed() -> void:
	UiHelper.app_message.show_message("This isn't implemented yet")

func _on_theme_color_button_pressed() -> void:
	var colors = SongoSettings.THEME_COLORS
	var current_index = colors.find(theme_color)
	var next_index = (current_index+1) % colors.size() 
	theme_color = colors[next_index]
	update_theme_color_preview()

# Update for first item in UI
func _on_add_new_dir_button_focus_entered() -> void:
	%ScrollContainer.scroll_vertical = 0

func _on_dev_credit_focus_entered() -> void:
	%ScrollContainer.scroll_vertical = 99999

func _on_global_ui_scale_button_pressed() -> void:
	ui_scale = ui_scale + 0.05
	if ui_scale >= 1.55: ui_scale = 0.5
	update_global_scale_ui()

func _on_apply_ui_button_pressed() -> void:
	songo_settings.ui_scale = ui_scale
	songo_settings.theme_color = theme_color
	songo_settings.clock_24_hour = clock_24_hour
	songo_settings.main_menu_size = main_menu_size
	songo_settings.save()
	
	UiHelper.apply_scale(ui_scale)
	UiHelper.apply_theme_color(theme_color)

	Controller.reload_settings_after_ui()

func _on_reset_ui_button_pressed() -> void:
	ui_scale = 1.0
	theme_color = SongoSettings.THEME_COLORS[0]
	clock_24_hour = false
	main_menu_size = 1
	update_global_scale_ui()
	update_theme_color_preview()
	update_clock_setting_ui()
	update_main_menu_size_ui()
	
	_on_apply_ui_button_pressed()

func _on_auto_import_toggle_button_pressed() -> void:
	songo_settings.auto_import = not songo_settings.auto_import
	songo_settings.save()
	update_auto_import_ui()

func _on_clock_24_hour_button_pressed() -> void:
	clock_24_hour = not clock_24_hour
	update_clock_setting_ui()

func _on_main_menu_size_button_pressed() -> void:
	main_menu_size = main_menu_size+1
	if main_menu_size >= 3: main_menu_size = 0 
	update_main_menu_size_ui()

func _on_use_targeted_strategy_pressed() -> void:
	songo_settings.use_generic_strategy = false
	songo_settings.save()
	await get_tree().process_frame
	if DeviceOS.device_strategy is not GenericLinuxStrategy:
		UiHelper.app_message.show_message("You are already using the strategy targeted for your cfw.")
	else:
		DeviceOS.set_device_os_strategy()
		if DeviceOS.device_strategy is GenericLinuxStrategy:
			UiHelper.app_message.show_message("It seems like Songo#5 doesn't support advanced features for your cfw yet, using GenericLinuxStrategy for now.")
		else:
			Controller.quit_songo()


func _on_use_generic_strategy_pressed() -> void:
	songo_settings.use_generic_strategy = true
	songo_settings.save()
	if DeviceOS.device_strategy is GenericLinuxStrategy:
		UiHelper.app_message.show_message("You are already using the GenericLinuxStrategy.")
	else:
		Controller.quit_songo()


func _on_song_sleep_timer_button_pressed() -> void:
	var times = [0,5,10,15,30,45,60]
	var index = times.find(songo_settings.song_sleep_timer) +1
	if index >= times.size(): index = 0
	songo_settings.song_sleep_timer = times[index]
	songo_settings.save()
	update_song_sleep_ui()


#func _on_force_screen_fit_button_pressed() -> void:
#	songo_settings.force_screen_fit = not songo_settings.force_screen_fit
#	update_force_screen_fit_ui()
#	songo_settings.save()
#	if songo_settings.force_screen_fit:
#		UiHelper.apply_screen_fit()

func _on_song_following_button_pressed() -> void:
	songo_settings.song_following = not songo_settings.song_following
	songo_settings.save()
	update_song_following_ui()


func _on_new_playlist_button_pressed() -> void:
	var keyboard = UiHelper.keyboard
	keyboard.setup("New Playlist Name", %NewPlaylistButton)
	keyboard.keyboard_result.connect(_keyboard_playlist_entered)

func _keyboard_playlist_entered(new_playlist_name):
		var keyboard = UiHelper.keyboard
		#%NewPlaylistButton.grab_focus()
		keyboard.keyboard_result.disconnect(_keyboard_playlist_entered)
		
		#var new_playlist = PlaylistRecord.build_from_name(new_playlist_name)
		
		var new_playlist = M3uCollection.create_collection("playlists", new_playlist_name)
		if new_playlist:
			songo_data.playlists.append(new_playlist)
			songo_data.recent_playlist_name = new_playlist.name
			songo_data.save()
			build_playlists_list()
		else:
			UiHelper.app_message.show_message("Something went wrong during playlist creation.")
