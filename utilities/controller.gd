extends Node

var songo_data = SongoDataResource.get_instance()
var songo_settings = SongoSettings.get_instance()
var content_body_node
var nav_label_node
var active_container
var container_history = []
signal page_changed
signal quitting_songo

var history = []
var nav_label = [] 
var navigating_back = false
var stored_state = null
var skip_refocus: bool = false
var _rebuilding_nav: bool = false

const MAIN_MENU = "res://scenes/theme_injections/theme_main_menu/theme_main_menu.tscn"
const ALL_SONGS_CONTAINER = "res://scenes/all_songs_container_v2/all_songs_container_v2.tscn"
const SONG_PANEL_CONTAINER = "res://scenes/theme_injections/theme_main_song_view/theme_main_song_view.tscn"
const SETTINGS_DIRECTORY_SELECT = "res://scenes/directory_container/directory_container.tscn"

const SETTINGS_SUB_PATH = "res://scenes/settings_container/sub_containers"
const DATA_AND_STORAGE_SUB_CONTAINER = SETTINGS_SUB_PATH + "/data_and_storage/data_and_storage.tscn"
const UI_AND_CUSTOMIZATIONS_SUB_CONTAINER = SETTINGS_SUB_PATH + "/ui_and_customization/ui_and_customization.tscn"
const MISC_FEATURE_SETTINGS_SUB_CONTAINER = SETTINGS_SUB_PATH + "/misc_feature_settings/misc_feature_settings.tscn"
const DEVELOPMENT_CREDIT_SUB_CONTAINER = SETTINGS_SUB_PATH + "/development_credit/development_credit.tscn"
const CONTACT_ME_SUB_CONTAINER = SETTINGS_SUB_PATH + "/contact_me/contact_me.tscn"
const SUPPORT_ME_SUB_CONTAINER = SETTINGS_SUB_PATH + "/support_me/support_me.tscn"
const CONTROLLER_SETTINGS_SUB_CONTAINER = SETTINGS_SUB_PATH + "/controller_settings/controller_settings.tscn"
const SOUND_SETTINGS_SUB_CONTAINER = SETTINGS_SUB_PATH + "/sound_settings/sound_settings.tscn"


var settings_collection : Array[SettingRecord] = [
	SettingRecord.new("Data and Storage", "settings_data_and_storage", false),
	SettingRecord.new("UI and Customization", "settings_ui_and_customizations", false),
	SettingRecord.new("Misc Feature Settings", "misc_feature_settings", false),
	SettingRecord.new("Controller Settings", "controller_settings", false),
	SettingRecord.new("Sound Settings", "sound_settings", false),
	SettingRecord.new("Development Credit", "settings_development_credit", true),
	SettingRecord.new("Contact Me / Report a bug", "contact_me", true),
	SettingRecord.new("Support Me / Dev Roadmap", "support_me", true),
]

var _menu_items: Array[MenuItemData] = [
	MenuItemData.new("All Songs", "res://assets/music.svg", songs_index),
	MenuItemData.new("Albums", "res://assets/record.svg", albums_index),
	MenuItemData.new("Artists", "res://assets/user.svg", artists_index),
	MenuItemData.new("Playlists", "res://assets/layergroup.svg", playlists_index),
	MenuItemData.new("Settings", "res://assets/gear.svg", settings_index),
	MenuItemData.new("Exit", "res://assets/exit_walk.svg", quit_songo),
]

# Maps a menu item's label to its key in SongoSettings.menu_visibility.
# Items with no entry here (Settings, Exit) are never hideable.
const _MENU_ITEM_VISIBILITY_KEYS := {
	"All Songs": "all_songs",
	"Albums": "albums",
	"Artists": "artists",
	"Playlists": "playlists",
}

var menu_items: Array[MenuItemData]:
	get:
		var visible_items: Array[MenuItemData] = []
		for item in _menu_items:
			var visibility_key = _MENU_ITEM_VISIBILITY_KEYS.get(item.label)
			if visibility_key == null or songo_settings.menu_visibility.get(visibility_key, true):
				visible_items.append(item)
		return visible_items


func collection_list(collection = null):
	if collection == null: collection = songo_data.music_records
	if collection is Array[M3uCollection] && collection.size() == 0:
		UiHelper.app_message.show_message("You need to create a playlist first, go to Settings.")
		return
	if collection is Array && collection.size() == 0:
		UiHelper.app_message.show_message("You need to import music first, go to Settings.")
		return
	if collection is Object && "music_records" in collection && collection.music_records.size() == 0 && collection is not M3uCollection:
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
		"SETTINGS": nav_label = ["Main Menu", "Settings"]
		"ALBUM_SONGS": nav_label = ["Main Menu", "Albums", CollectionHelper.collection_name]
		"ARTIST_SONGS": nav_label = ["Main Menu", "Artists", CollectionHelper.collection_name]
		"PLAYLIST_SONGS": nav_label = ["Main Menu", "Playlists", CollectionHelper.collection_name]
		_: nav_label = ["Main Menu", CollectionHelper.collection_name]
	finish_up_nav()

func songs_index():
	collection_list()
	
	
func albums_index():
	var albums = songo_data.albums
	collection_list(albums)
	
func artists_index():
	var artists = songo_data.artists
	collection_list(artists)
	
func playlists_index():
	var playlists = songo_data.playlists
	collection_list(playlists)
	
func songs_panel(music_records, play_index, play_mode = SongoPlayer.MODE.LINEAR):
	clean_up_old_container()

	SongoPlayer.play_index = play_index
	SongoPlayer.set_music_records(music_records)
	SongoPlayer.repeating = false
	SongoPlayer.setMode(play_mode)
	
	if SongoPlayer.is_playing() == false || SongoPlayer.get_current_music_record() != music_records[play_index]:
		SongoPlayer.play_from_start()
		
	active_container = load(SONG_PANEL_CONTAINER).instantiate()
	active_container.setup()

	finish_up_nav()
	
func settings_directory_select(path_array = []):
	clean_up_old_container()
	
	active_container = load(SETTINGS_DIRECTORY_SELECT).instantiate()
	active_container.setup(path_array)
	nav_label = ["Main Menu", "Settings", "Data and Storage", "Adding New"]
	finish_up_nav()
	
func settings_index():
	collection_list(settings_collection)

	
func settings_data_and_storage():
	print("Got to data an storage?")
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
	
func plugin_settings(plugin: SongoPlugin, scene_path: String):
	clean_up_old_container()
	active_container = load(scene_path).instantiate()
	if active_container.has_method("setup"): active_container.setup(plugin)
	nav_label = ["Main Menu", "Settings", plugin.plugin_name]
	finish_up_nav()

## Plugin items slot in ahead of Settings/Exit, which themes render as the
## trailing pair.
func add_menu_item(item: MenuItemData):
	var insert_at = _menu_items.size()
	for i in range(_menu_items.size()):
		if _menu_items[i].action == settings_index:
			insert_at = i
			break
	_menu_items.insert(insert_at, item)

## Plugin settings pages slot in ahead of the info pages (credits, contact...).
func add_settings_record(record: SettingRecord):
	var insert_at = settings_collection.size()
	for i in range(settings_collection.size()):
		if settings_collection[i].is_info:
			insert_at = i
			break
	settings_collection.insert(insert_at, record)

func main_menu():
	CollectionHelper.current_collection = null
	clean_up_old_container()
	active_container = load(MAIN_MENU).instantiate()
	active_container.setup()
	nav_label = ["Main Menu"]
	finish_up_nav()
	
func quit_songo():
	SfxPlayer.play_accept_sfx()
	quitting_songo.emit()
	#UiHelper.darkout.show()
	#content_body_node.get_node("ExitingOverlay").show()
	SongoPlayer.save_listens()
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

## Quits and leaves the queue playing: writes it out, stops our playback and
## hands over to the background player in the same frame, along with the
## playback blend time. The launcher's start script detaches the player, so
## it isn't Songo's child once Songo exits, and it takes over the playback
## suppressions. Quits normally if the launcher doesn't support it or nothing
## is playing.
func quit_songo_with_music():
	var playlist_path := OS.get_environment("SONGO_BG_PLAYLIST_PATH")
	var start_path := OS.get_environment("SONGO_BG_PLAY_START_PATH")
	if not playlist_path.is_empty() and not start_path.is_empty() \
			and SongoPlayer.write_background_playlist(playlist_path):
		SongoPlayer.stop_for_background_handoff()
		var blend_time := "%.2f" % songo_settings.playback_blend_time
		OS.create_process("sh", [start_path, playlist_path, blend_time])
	quit_songo()

##################################
#           HELPERS              #
##################################

	
func append_container_history(container):
	var focused = get_viewport().gui_get_focus_owner()
	var new_history = [container, focused, nav_label]
	if not _rebuilding_nav: SfxPlayer.play_accept_sfx()
	container_history.append(new_history)
	
func nav_back():
	SfxPlayer.play_back_sfx()
	var target_container = container_history.pop_back()
	if target_container != null:
		content_body_node.remove_child(active_container)
		active_container = target_container[0]
		if "collection" in active_container:
			CollectionHelper.current_collection = active_container.collection
		else:
			CollectionHelper.current_collection = null
		nav_label = target_container[2]
		finish_up_nav()
		await get_tree().process_frame
		call_deferred("restore_focus", target_container[1])
	

func nav_back_to_settings():
	var history_cnt = container_history.size()
	for i in range(history_cnt):
		if i == history_cnt-1: break
		var back_i = history_cnt-1-i
		var container = container_history[back_i][0]
		if "collection" in container && container.collection[0] is SettingRecord:
			break
		else:
			container_history.pop_back()
	nav_back()

func restore_focus(control: Control):
	if skip_refocus:
		skip_refocus = false
	elif is_instance_valid(control) && control.is_inside_tree():
		control.grab_focus()

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

## Throws away the navigation history and rebuilds it as if the user had walked
## Main Menu > index page > collection by hand, so back navigation behaves
## normally afterwards. `index_action` is the main menu action whose list holds
## `collection` (e.g. albums_index). The final list lands on its first item.
## Leaving the song view follows the same rules as pressing back.
func rebuild_nav_to_collection(index_action: Callable, collection) -> void:
	if _rebuilding_nav: return
	_rebuilding_nav = true
	SfxPlayer.play_accept_sfx()

	var song_view = active_container if active_container is ThemeMainSongView else null
	var keep_song_view = song_view != null && SongoPlayer.is_playing() && songo_settings.song_following
	# Grab the song view's focus (e.g. play/pause) before detaching it, so
	# returning via song follow restores it like a normal back press would.
	var song_view_focus = null
	if keep_song_view:
		var focused = get_viewport().gui_get_focus_owner()
		if focused != null && song_view.is_ancestor_of(focused): song_view_focus = focused
	if song_view != null && not keep_song_view:
		SongoPlayer.stop()

	# Detach and free everything the old history references, except the song
	# view when it's being kept around for song following.
	var stale = [active_container]
	for entry in container_history: stale.append(entry[0])
	if stored_state != null:
		stale.append(stored_state["active_container"])
		for entry in stored_state["container_history"]: stale.append(entry[0])
	if is_instance_valid(active_container) && active_container.is_inside_tree():
		content_body_node.remove_child(active_container)
	for container in stale:
		if is_instance_valid(container) && container != song_view:
			container.queue_free()
	if song_view != null && not keep_song_view:
		song_view.queue_free()

	active_container = null
	container_history = []
	stored_state = null
	nav_label = []
	get_viewport().gui_release_focus()

	# Frames are awaited between steps so each page's deferred focus grabs land
	# before we move on, and our own focus wins.
	main_menu()
	await get_tree().process_frame
	await get_tree().process_frame
	_focus_button_for_action(active_container, index_action)

	# collection_list() bails with an app message on empty collections, leaving
	# us on the previous page; stop there rather than building on the wrong one.
	index_action.call()
	await get_tree().process_frame
	if active_container is AllSongsContainerV2:
		active_container.virtualized_list.focus_index(active_container.list_items.find(collection))

		collection_list(collection)
		await get_tree().process_frame
		if active_container is AllSongsContainerV2 && active_container.collection == collection:
			active_container.virtualized_list.focus_first()
			if keep_song_view: _swap_player_queue_to(active_container.list_items)

	if keep_song_view:
		# Mirrors save_state() from the song view, as if the song had been
		# picked from this list, so select/back from song follow line up.
		stored_state = {
			"active_container": song_view,
			"container_history": container_history + [[active_container, get_viewport().gui_get_focus_owner(), nav_label]],
			"nav_label": nav_label,
			"focused": song_view_focus,
		}
	_rebuilding_nav = false

# Points the player's queue at `music_records` (in list order) without
# interrupting playback. Skipped if the current song isn't in the list, e.g. the
# track changed while the info panel was open.
func _swap_player_queue_to(music_records) -> void:
	var current = SongoPlayer.get_current_music_record()
	if current == null: return
	for i in range(music_records.size()):
		if music_records[i].full_path == current.full_path:
			SongoPlayer.swap_music_records_silently(music_records, i)
			return

func _focus_button_for_action(node: Node, action: Callable) -> bool:
	if node is BaseButton && node.is_visible_in_tree() && node.pressed.is_connected(action):
		node.grab_focus()
		return true
	for child in node.get_children():
		if _focus_button_for_action(child, action): return true
	return false
