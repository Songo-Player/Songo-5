extends ScrollContainer
var songo_data = SongoDataResource.get_instance()
var songo_settings = SongoSettings.get_instance()
var tex_panels = []
var default_focus
var red_focus


const TEX_PANEL_SIZES=[Vector2(124, 124), Vector2(172, 172), Vector2(220, 220)]

func setup():
	call_deferred("focus_valid_nav_item")
	await ready
	tex_panels.append(%AllSongsTextureRect)
	tex_panels.append(%AlbumsTextureRect)
	tex_panels.append(%ArtistsTextureRect)
	tex_panels.append(%PlaylistsTextureRect)
	update_main_menu_size()
	
	var hover_behavior_tweaks = [
		%AllSongsMenuItem,
		%AlbumsMenuItem,
		%ArtistsMenuItem,
		%PlaylistsMenuItem,
		%SettingsMenuItem,
		%ExitMenuItem
	]
	for item in hover_behavior_tweaks:
		var child: Control = item.get_child(0)
		if default_focus == null:
			default_focus = child.get_theme_stylebox("focus").duplicate()
			red_focus = default_focus.duplicate()
			red_focus.border_color = Color("8d0000")
			red_focus.border_width_bottom = 4
			red_focus.border_width_top = 4
			red_focus.border_width_left = 4
			red_focus.border_width_right = 4
			red_focus.draw_center = false 
		
		if ["fff", "eee"].has(songo_settings.theme_color):
			child.add_theme_stylebox_override("focus", red_focus)
		else:
			child.add_theme_stylebox_override("focus", default_focus)
			
		child.mouse_entered.connect(func(): child.grab_focus())
	
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
			
	var button_containers = [
		%AllSongsMenuItem,
		%AlbumsMenuItem,
		%ArtistsMenuItem,
		%PlaylistsMenuItem,
		%SettingsMenuItem,
		%ExitMenuItem
	]
	for item in button_containers:
		var child: Control = item.get_child(0)
		if ["fff", "eee"].has(songo_settings.theme_color):
			child.add_theme_stylebox_override("focus", red_focus)
		else:
			child.add_theme_stylebox_override("focus", default_focus)
			
func _on_resized() -> void:
	var target_size = songo_settings.main_menu_size
	if UiHelper.mini_song_panel.visible == true && target_size == 2:
		target_size = 1

	for tex_panel in tex_panels:
		tex_panel.custom_minimum_size = TEX_PANEL_SIZES[target_size]
		
func _on_playlists_menu_button_pressed() -> void:
	Controller.playlists_index(songo_data.playlists)

func _on_all_songs_menu_button_mouse_entered() -> void:
	%AllSongsMenuItem.get_child(0).grab_focus()

func _on_all_songs_menu_button_mouse_exited() -> void:
	%AllSongsMenuItem.get_child(0).release_focus()
