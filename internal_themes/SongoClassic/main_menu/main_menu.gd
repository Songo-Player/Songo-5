extends ScrollContainer

var songo_settings = SongoSettings.get_instance()
var tex_panels = []

func _ready():
	focus_valid_nav_item()
	tex_panels = [%AllSongsTextureRect, %AlbumsTextureRect, %ArtistsTextureRect, %PlaylistsTextureRect]
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
		child.mouse_entered.connect(func(): child.grab_focus())


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
	
	
func _on_all_songs_menu_button_pressed() -> void:
	Controller.songs_index()

func _on_album_menu_button_pressed() -> void:
	Controller.albums_index()

func _on_settings_menu_button_pressed() -> void:
	Controller.settings_index()

func _on_exit_menu_button_pressed() -> void:
	Controller.quit_songo()

func _on_artist_menu_button_pressed() -> void:
	Controller.artists_index()

func update_main_menu_size():
	var size = ThemeManager.settings["songo_main_menu_size"]
	if UiHelper.mini_song_panel.visible == true && size == 220:
		size = 172
		
	for tex_panel in tex_panels: 
		tex_panel.custom_minimum_size = Vector2(size, size)

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
	update_main_menu_size()
		
func _on_playlists_menu_button_pressed() -> void:
	Controller.playlists_index()

func _on_all_songs_menu_button_mouse_entered() -> void:
	%AllSongsMenuItem.get_child(0).grab_focus()

func _on_all_songs_menu_button_mouse_exited() -> void:
	%AllSongsMenuItem.get_child(0).release_focus()
