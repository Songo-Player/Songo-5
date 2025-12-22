extends ScrollContainer
class_name MainMenu
var songo_data = SongoDataResource.get_instance()
var songo_settings = SongoSettings.get_instance()
var tex_panels = []


const TEX_PANEL_SIZES=[Vector2(124, 124), Vector2(172, 172), Vector2(220, 220)]

func setup():
	call_deferred("focus_valid_nav_item")
	await ready
	tex_panels.append(%AllSongsTextureRect)
	tex_panels.append(%AlbumsTextureRect)
	tex_panels.append(%ArtistsTextureRect)
	tex_panels.append(%PlaylistsTextureRect)
	update_main_menu_size()
	
	#var menu_tex_panels = get_tree().get_nodes_in_group("menu_tex_panel")
	#for tex_panel in menu_tex_panels:
	#	var size_index = songo_settings.main_menu_size
	#	tex_panel.custom_minimum_size = TEX_PANEL_SIZES[size_index]

func focus_valid_nav_item():
	var items = [
		%AllSongsMenuItem,
		%AlbumsMenuItem,
		%ArtistsMenuItem,
		%PlaylistsMenuItem
		]
		
	for item in items:
		if item.visible == true:
			item.get_child(0).grab_focus()
			return
			
	%SettingsMenuItem.get_child(0).grab_focus()
	
func render_ui():
	pass
	
func handle_input(delta: float):
	pass
	
func _on_all_songs_menu_button_pressed() -> void:
	Controller.songs_index(songo_data.music_records)

func _on_album_menu_button_pressed() -> void:
	Controller.albums_index(songo_data.albums)

func _on_settings_menu_button_pressed() -> void:
	Controller.settings_index()

func _on_exit_menu_button_pressed() -> void:
	Controller.quit_songo()

func _on_artist_menu_button_pressed() -> void:
	Controller.artists_index(songo_data.artists)

func update_main_menu_size():
	for tex_panel in tex_panels:
		var size_index = songo_settings.main_menu_size
		tex_panel.custom_minimum_size = TEX_PANEL_SIZES[size_index]

func _on_tree_entered() -> void:
	update_main_menu_size()
	if songo_settings.main_menu_visible["all_songs"]: %AllSongsMenuItem.show()
	else: %AllSongsMenuItem.hide()
	
	if songo_settings.main_menu_visible["albums"]: %AlbumsMenuItem.show()
	else: %AlbumsMenuItem.hide()
	
	if songo_settings.main_menu_visible["artists"]: %ArtistsMenuItem.show()
	else: %ArtistsMenuItem.hide()
	
	if songo_settings.main_menu_visible["playlists"]: %PlaylistsMenuItem.show()
	else: %PlaylistsMenuItem.hide()
	
	%FlameContainer.show()
	for value in songo_settings.main_menu_visible.values():
		if value:
			%FlameContainer.hide()

func _on_resized() -> void:
	var target_size = songo_settings.main_menu_size
	if UiHelper.mini_song_panel.visible == true && target_size == 2:
		target_size = 1

	for tex_panel in tex_panels:
		tex_panel.custom_minimum_size = TEX_PANEL_SIZES[target_size]
		
func _on_playlists_menu_button_pressed() -> void:
	Controller.playlists_index(songo_data.playlists)
