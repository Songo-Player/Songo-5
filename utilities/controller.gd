extends Node

var songo_data = SongoDataResource.get_instance()
var content_body_node
var nav_label_node
var active_container
var container_history = []
signal page_changed

var history = []
var nav_label = [] 
var navigating_back = false
var stored_state = null
var skip_refocus: bool = false

#const MAIN_MENU = "res://scenes/main_menu/main_menu.tscn"
const MAIN_MENU = "res://scenes/theme_injections/theme_main_menu/theme_main_menu.tscn"
const ALL_SONGS_CONTAINER = "res://scenes/all_songs_container_v2/all_songs_container_v2.tscn"
#const SONG_PANEL_CONTAINER = "res://scenes/song_panel_container/song_panel_container.tscn"
const SONG_PANEL_CONTAINER = "res://scenes/theme_injections/theme_main_song_view/theme_main_song_view.tscn"
const ALBUMS_CONTAINER = "res://scenes/albums_container/albums_container.tscn"
const SETTINGS_DIRECTORY_SELECT = "res://scenes/directory_container/directory_container.tscn"
const ARTISTS_CONTAINER = "res://scenes/artists_container/artists_container.tscn"
const SETTINGS_CONTAINER = "res://scenes/settings_container/settings_container.tscn"
const PLAYLISTS_CONTAINER = "res://scenes/playlists_container/playlists_container.tscn"

const SETTINGS_V2_CONTAINER = "res://scenes/settings_container/v2/settings_container_v2.tscn"
const DATA_AND_STORAGE_SUB_CONTAINER = "res://scenes/settings_container/v2/sub_containers/data_and_storage_sub_container.tscn"
const UI_AND_CUSTOMIZATIONS_SUB_CONTAINER = "res://scenes/settings_container/v2/sub_containers/ui_and_customization_sub_container.tscn"
const MISC_FEATURE_SETTINGS_SUB_CONTAINER = "res://scenes/settings_container/v2/sub_containers/misc_feature_settings_sub_container.tscn"
const PLAYLIST_SETTINGS_SUB_CONTAINER = "res://scenes/settings_container/v2/sub_containers/playlist_settings_sub_container.tscn"
const DEVELOPMENT_CREDIT_SUB_CONTAINER = "res://scenes/settings_container/v2/sub_containers/development_credit_sub_container.tscn"
const CONTACT_ME_SUB_CONTAINER = "res://scenes/settings_container/v2/sub_containers/contact_me_sub_container.tscn"
const SUPPORT_ME_SUB_CONTAINER = "res://scenes/settings_container/v2/sub_containers/support_me_sub_container.tscn"
const CONTROLLER_SETTINGS_SUB_CONTAINER = "res://scenes/settings_container/v2/sub_containers/controller_settings_sub_container.tscn"
const SOUND_SETTINGS_SUB_CONTAINER = "res://scenes/settings_container/v2/sub_containers/sound_settings_sub_container.tscn"

func collection_list(collection = null):
	if collection == null: collection = songo_data.music_records
	if collection is Array[M3uCollection] && collection.size() == 0:
		UiHelper.app_message.show_message("You need to create a playlist first, go to Settings.")
		return
	if collection is Array && collection.size() == 0:
		UiHelper.app_message.show_message("You need to import music first, go to Settings.")
		return
	if "music_records" in collection && collection.music_records.size() == 0 && collection is not M3uCollection:
		UiHelper.app_message.show_message("This Collection is empty, try reimporting.")
		return
	
	clean_up_old_container()
	CollectionHelper.current_collection = collection
	active_container = load(ALL_SONGS_CONTAINER).instantiate()
	active_container.setup_collection(collection)
	var collection_type = CollectionHelper.collection_type
	match collection_type:
		"ALL_SONGS": nav_label = ["Main Menu", "All Songs"]
		"ALBUMS": nav_label = ["Main Menu", "Albums"]
		"ARTISTS": nav_label = ["Main Menu", "Artists"]
		"PLAYLISTS": nav_label = ["Main Menu", "Playlists"]
		"ALBUM_SONGS": nav_label = ["Main Menu", "Albums", CollectionHelper.collection_name]
		"ARTIST_SONGS": nav_label = ["Main Menu", "Artists", CollectionHelper.collection_name]
		"PLAYLIST_SONGS": nav_label = ["Main Menu", "Playlists", CollectionHelper.collection_name]
		_: nav_label = ["Main menu", "Collection"]
	finish_up_nav()

func songs_index():
	collection_list()
	return
	var music_records = songo_data.music_records
	if music_records is Array[MusicRecord]:
		print("hmmm OK")
	if music_records.size() == 0:
		UiHelper.app_message.show_message("You need to import music first, go to Settings.")
		return

	clean_up_old_container()
	
	active_container = load(ALL_SONGS_CONTAINER).instantiate()
	active_container.setup(music_records)
	nav_label = ["Main Menu", "All Songs"]
	finish_up_nav()
	
func album_songs_index(album):
	var music_records = album.music_records
	if music_records.size() == 0:
		UiHelper.app_message.show_message("Something went wrong, this album seems to have no music associated to it.")
		return
		
	clean_up_old_container()
	
	active_container = load(ALL_SONGS_CONTAINER).instantiate()
	active_container.setup(music_records)
	active_container.set_as_album(album)
	nav_label = ["Main Menu", "Albums", album.name]
	finish_up_nav()
	
func albums_index():
	var albums = songo_data.albums
	collection_list(albums)
	return
	if albums.size() == 0:
		UiHelper.app_message.show_message("You need to import music first, go to Settings.")
		return
	clean_up_old_container()
	
	active_container = load(ALBUMS_CONTAINER).instantiate()
	active_container.setup(albums)
	nav_label = ["Main Menu", "Albums"]
	finish_up_nav()
	
func artists_index():
	var artists = songo_data.artists
	collection_list(artists)
	return
	if artists.size() == 0:
		UiHelper.app_message.show_message("You need to import music first, go to Settings.")
		return
	clean_up_old_container()
	
	active_container = load(ARTISTS_CONTAINER).instantiate()
	active_container.setup(artists)
	nav_label = ["Main Menu", "Artists"]
	finish_up_nav()
	
func playlists_index():
	var playlists = songo_data.playlists
	collection_list(playlists)
	return
	if playlists.size() == 0:
		UiHelper.app_message.show_message("You need to create a playlist first, go to Settings.")
		return
	clean_up_old_container()
	
	active_container = load(PLAYLISTS_CONTAINER).instantiate()
	active_container.setup(playlists)
	nav_label = ["Main Menu", "Playlists"]
	finish_up_nav()
	
func playlist_songs_index(playlist):
	songo_data.recent_playlist_name = playlist.name
	var music_records = playlist.music_records		
	clean_up_old_container()
	
	active_container = load(ALL_SONGS_CONTAINER).instantiate()
	active_container.setup(music_records)
	active_container.set_as_playlist(playlist)
	nav_label = ["Main Menu", "Playlists", playlist.name]
	finish_up_nav()
	
func artist_songs_index(artist):
	var music_records = artist.music_records
	if music_records.size() == 0:
		UiHelper.app_message.show_message("Something went wrong, this artist seems to have no music associated to them.")
		return
		
	clean_up_old_container()
	
	active_container = load(ALL_SONGS_CONTAINER).instantiate()
	active_container.setup(music_records)
	active_container.set_as_artist(artist)
	nav_label = ["Main Menu", "Artists", artist.name]
	finish_up_nav()
	
func songs_panel(music_records, play_index, play_mode = SongoPlayerV2.MODE.LINEAR):
	clean_up_old_container()

	SongoPlayerV2.play_index = play_index
	SongoPlayerV2.set_music_records(music_records)
	SongoPlayerV2.repeating = false
	SongoPlayerV2.setMode(play_mode)
	
	if SongoPlayerV2.is_playing() == false || SongoPlayerV2.get_current_music_record() != music_records[play_index]:
		SongoPlayerV2.play_from_start()
		
	active_container = load(SONG_PANEL_CONTAINER).instantiate()
	active_container.setup()

	finish_up_nav()

	#	active_container.play()
	
func settings_directory_select(path_array = []):

	clean_up_old_container()
	
	active_container = load(SETTINGS_DIRECTORY_SELECT).instantiate()
	active_container.setup(path_array)
	nav_label = ["Main Menu", "Settings", "Data and Storage", "Adding New"]
	finish_up_nav()
	
func settings_index():
	clean_up_old_container()
	
	active_container = load(SETTINGS_V2_CONTAINER).instantiate()
	active_container.setup()
	nav_label = ["Main Menu", "Settings"]
	finish_up_nav()
	
func settings_data_and_storage():
	clean_up_old_container()
	
	active_container = load(DATA_AND_STORAGE_SUB_CONTAINER).instantiate()
	active_container.setup()
	nav_label = ["Main Menu", "Settings", "Data and Storage"]
	finish_up_nav()

func settings_ui_and_customizations():
	clean_up_old_container()
	
	active_container = load(UI_AND_CUSTOMIZATIONS_SUB_CONTAINER).instantiate()
	active_container.setup()
	nav_label = ["Main Menu", "Settings", "UI and Customizations"]
	finish_up_nav()


func misc_feature_settings():
	clean_up_old_container()
	
	active_container = load(MISC_FEATURE_SETTINGS_SUB_CONTAINER).instantiate()
	active_container.setup()
	nav_label = ["Main Menu", "Settings", "Misc Feature Settings"]
	finish_up_nav()
	
func playlist_settings():
	clean_up_old_container()
	
	active_container = load(PLAYLIST_SETTINGS_SUB_CONTAINER).instantiate()
	active_container.setup()
	nav_label = ["Main Menu", "Settings", "Playlist Settings"]
	finish_up_nav()
	
func settings_development_credit():
	clean_up_old_container()
	
	active_container = load(DEVELOPMENT_CREDIT_SUB_CONTAINER).instantiate()
	active_container.setup()
	nav_label = ["Main Menu", "Settings", "Development Credit"]
	finish_up_nav()
	
	
func contact_me():
	clean_up_old_container()
	active_container = load(CONTACT_ME_SUB_CONTAINER).instantiate()
	active_container.setup()
	nav_label = ["Main Menu", "Settings", "Contact Me"]
	finish_up_nav()
	
func support_me():
	clean_up_old_container()
	active_container = load(SUPPORT_ME_SUB_CONTAINER).instantiate()
	active_container.setup()
	nav_label = ["Main Menu", "Settings", "Support Me"]
	finish_up_nav()
	
func controller_settings():
	clean_up_old_container()
	active_container = load(CONTROLLER_SETTINGS_SUB_CONTAINER).instantiate()
	active_container.setup()
	nav_label = ["Main Menu", "Settings", "Controller Settings"]
	finish_up_nav()
	
func sound_settings():
	clean_up_old_container()
	active_container = load(SOUND_SETTINGS_SUB_CONTAINER).instantiate()
	active_container.setup()
	nav_label = ["Main Menu", "Settings", "Sound Settings"]
	finish_up_nav()
	
func main_menu():
	CollectionHelper.current_collection = null
	clean_up_old_container()
	active_container = load(MAIN_MENU).instantiate()
	active_container.setup()
	nav_label = ["Main Menu"]
	finish_up_nav()
	
func quit_songo():
	SfxPlayer.play_accept_sfx()
	UiHelper.dark_out.show()
	content_body_node.get_node("ExitingOverlay").show()
	await get_tree().process_frame
	get_tree().quit()
	
##################################
#           HELPERS              #
##################################

	
func append_container_history(container):
	var focused = get_viewport().gui_get_focus_owner()
	var new_history = [container, focused, nav_label]
	SfxPlayer.play_accept_sfx()
	container_history.append(new_history)
	
func new_nav_back():
	var target_container = container_history.pop_back()
	if target_container != null:
		#if stored_state == null:
		#active_container.queue_free()
		content_body_node.remove_child(active_container)
		active_container = target_container[0]
		if "collection" in active_container:
			CollectionHelper.current_collection = active_container.collection
		nav_label = target_container[2]
		finish_up_nav()
		await get_tree().process_frame
		call_deferred("restore_focus", target_container[1])
		
func nav_back_to_settings():
	var history_cnt = container_history.size()
	for i in range(history_cnt):
		if i == history_cnt-1: break
		var back_i = history_cnt-1-i
		if container_history[back_i][0] is SettingsV2Container:
			container_history.pop_back()
			break
		else:
			container_history.pop_back()
	active_container.queue_free()
	active_container = load(SETTINGS_V2_CONTAINER).instantiate()
	active_container.setup()
	nav_label = ["Main Menu", "Settings"]
	finish_up_nav()

func restore_focus(control: Control):
	if skip_refocus:
		skip_refocus = false
	else:
		control.grab_focus()
		
func reload_settings_after_ui():
	active_container.queue_free()
	await get_tree().process_frame
	active_container = load(SETTINGS_CONTAINER).instantiate()
	active_container.setup()
	nav_label = ["Main Menu", "Settings"]
	finish_up_nav()
	active_container.refocus()
	await get_tree().process_frame


func clean_up_old_container():
	append_container_history(active_container)
	if is_instance_valid(active_container):
		content_body_node.remove_child(active_container)

func finish_up_nav():
	content_body_node.add_child(active_container)
	#nav_label_node.text = " > ".join(nav_label)
	page_changed.emit()

func save_state():
	var new_state = {}
	new_state["active_container"] = active_container
	new_state["container_history"] = container_history.duplicate()
	new_state["nav_label"] = nav_label
	new_state["focused"] = get_viewport().gui_get_focus_owner()
	stored_state = new_state

func restore_state():
	if stored_state == null: return
	
	var target_container = stored_state["active_container"]
	content_body_node.remove_child(active_container)
	#active_container.queue_free()
	active_container = target_container
	nav_label = stored_state["nav_label"]
	container_history = stored_state["container_history"]
	var focus_target = stored_state["focused"]
	finish_up_nav()
	await get_tree().process_frame
	call_deferred("restore_focus", focus_target)
