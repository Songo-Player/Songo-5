extends ScrollContainer
class_name MainMenu
var songo_data = SongoDataResource.get_instance()

func setup():
	call_deferred("focus_all_songs")

func focus_all_songs():
	%AllSongsMenuItem.get_child(0).grab_focus()
	
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
	#Controller.settings_directory_select()

func _on_exit_menu_button_pressed() -> void:
	Controller.quit_songo()

func _on_artist_menu_button_pressed() -> void:
	Controller.artists_index(songo_data.artists)
