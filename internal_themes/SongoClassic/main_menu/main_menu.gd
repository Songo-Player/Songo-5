extends ScrollContainer

var songo_settings = SongoSettings.get_instance()
var tex_panels = []

func _ready():
	tex_panels = [%AllSongsTextureRect, %AlbumsTextureRect, %ArtistsTextureRect, %PlaylistsTextureRect]
	update_main_menu_size()
	await get_tree().process_frame
	focus_valid_nav_item()
	
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
	if SongoPlayerV2.is_playing() && size == 220:
		size = 172
		
	for tex_panel in tex_panels: 
		tex_panel.custom_minimum_size = Vector2(size, size)

func _on_tree_entered() -> void:
	update_main_menu_size()
	%FlameContainer.show()
	if ThemeManager.settings["songo_all_songs_menu_visibility"]: 
		%AllSongsMenuItem.show()
		%FlameContainer.hide()
	else: %AllSongsMenuItem.hide()
	
	if ThemeManager.settings["songo_albums_menu_visibility"]:
		%AlbumsMenuItem.show()
		%FlameContainer.hide()
	else: %AlbumsMenuItem.hide()
	
	if ThemeManager.settings["songo_artists_menu_visibility"]:
		%ArtistsMenuItem.show()
		%FlameContainer.hide()
	else: %ArtistsMenuItem.hide()
	
	if ThemeManager.settings["songo_playlists_menu_visibility"]:
		%PlaylistsMenuItem.show()
		%FlameContainer.hide()
	else: %PlaylistsMenuItem.hide()

func _on_resized() -> void:
	update_main_menu_size()
		
func _on_playlists_menu_button_pressed() -> void:
	Controller.playlists_index()

func _on_all_songs_menu_button_mouse_entered() -> void:
	%AllSongsMenuItem.get_child(0).grab_focus()

func _on_all_songs_menu_button_mouse_exited() -> void:
	%AllSongsMenuItem.get_child(0).release_focus()
