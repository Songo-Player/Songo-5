extends MarginContainer

var songo_settings = SongoSettings.get_instance()
var songo_data = SongoDataResource.get_instance()

func setup():
	build_playlists_list()
	
func _ready():
	await get_tree().process_frame
	%PageLabel.grab_focus()
	%PlaylistPathLabel.text = ProjectSettings.globalize_path("user://playlists")
func render_ui():
	pass
	
func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.new_nav_back()
	
func _on_tree_entered() -> void:
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

func _on_tree_exiting() -> void:
	get_viewport().gui_focus_changed.disconnect(_on_focus_changed)

func _on_focus_changed(item: Control):
	if item == %PlaylistPathLabel:
		%ScrollContainer.scroll_vertical = 999
		
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
	if songo_data.playlists.size() == 0: %DefaultPlaylistsLabel.show()
	else: %DefaultPlaylistsLabel.hide()

func _on_new_playlist_button_pressed() -> void:
	var keyboard = UiHelper.keyboard
	keyboard.setup("New Playlist Name", %NewPlaylistButton)
	keyboard.keyboard_result.connect(_keyboard_playlist_entered)
	
func _keyboard_playlist_entered(new_playlist_name):
		var keyboard = UiHelper.keyboard
		keyboard.keyboard_result.disconnect(_keyboard_playlist_entered)
		var new_playlist = M3uCollection.create_collection("playlists", new_playlist_name)
		if new_playlist:
			songo_data.playlists.append(new_playlist)
			songo_data.recent_playlist_name = new_playlist.name
			songo_data.save()
			build_playlists_list()
		else:
			UiHelper.app_message.show_message("Something went wrong during playlist creation.")
