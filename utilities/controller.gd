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
## The list the player's queue was picked from, for faking the path back to it.
var queue_source: SavedQueueSource = null

## Stands in for a collection page in container_history without building it.
## nav_back builds the page when it's popped and focuses `focus_index`, so
## rebuilt history only pays for the pages the user actually walks back through.
class CollectionBuildRequest:
	var collection
	var focus_index: int

	func _init(collection_arg, focus_index_arg: int = 0):
		collection = collection_arg
		focus_index = focus_index_arg

## Stands in for the main menu in container_history, like CollectionBuildRequest.
## nav_back builds it and focuses the button for `focus_action` (e.g. albums_index).
class MainMenuBuildRequest:
	var focus_action: Callable

	func _init(focus_action_arg: Callable):
		focus_action = focus_action_arg

func _ready() -> void:
	# Music left playing by "Quit with Music" picks up where it was picked from
	SongoPlayer.resumed_leftover_playback.connect(func(): queue_source = SavedQueueSource.take())

const MAIN_MENU = "res://scenes/theme_injections/theme_main_menu/theme_main_menu.tscn"
const ALL_SONGS_CONTAINER = "res://scenes/all_songs_container_v2/all_songs_container_v2.tscn"
const SONG_PANEL_CONTAINER = "res://scenes/theme_injections/theme_main_song_view/theme_main_song_view.tscn"
# Pages are told apart by scene rather than by class (`is ThemeMainSongView`), so
# their scripts and the list code they use don't compile before the first screen.
func is_song_view(node) -> bool:
	return is_instance_valid(node) && node.scene_file_path == SONG_PANEL_CONTAINER

func is_song_list(node) -> bool:
	return is_instance_valid(node) && node.scene_file_path == ALL_SONGS_CONTAINER

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
	if not _can_open_collection(collection): return

	clean_up_old_container()
	_open_collection(collection)
	finish_up_nav()

## Shows the matching app message and returns false if `collection` is empty.
func _can_open_collection(collection) -> bool:
	if collection is Array[M3uCollection] && collection.size() == 0:
		UiHelper.app_message.show_message("You need to create a playlist first, go to Settings.")
		return false
	if collection is Array && collection.size() == 0:
		UiHelper.app_message.show_message("You need to import music first, go to Settings.")
		return false
	if collection is Object && "music_records" in collection && collection.music_records.size() == 0 && collection is not M3uCollection:
		UiHelper.app_message.show_message("This Collection is empty, try reimporting.")
		return false
	return true

## Builds the list page for `collection` as the active container. Doesn't touch
## history or add it to the tree; callers handle both.
func _open_collection(collection) -> void:
	CollectionHelper.current_collection = collection
	active_container = load(ALL_SONGS_CONTAINER).instantiate()
	if CollectionHelper.sort_options.size() == 0:
		active_container.setup_collection(collection)
	else:
		active_container.setup_collection(collection.duplicate())
	_set_nav_label_for_current_collection()

func _set_nav_label_for_current_collection() -> void:
	match CollectionHelper.collection_type:
		"ALL_SONGS": nav_label = ["Main Menu", "All Songs"]
		"ALBUMS": nav_label = ["Main Menu", "Albums"]
		"ARTISTS": nav_label = ["Main Menu", "Artists"]
		"PLAYLISTS": nav_label = ["Main Menu", "Playlists"]
		"SETTINGS": nav_label = ["Main Menu", "Settings"]
		"ALBUM_SONGS": nav_label = ["Main Menu", "Albums", CollectionHelper.collection_name]
		"ARTIST_SONGS": nav_label = ["Main Menu", "Artists", CollectionHelper.collection_name]
		"PLAYLIST_SONGS": nav_label = ["Main Menu", "Playlists", CollectionHelper.collection_name]
		_: nav_label = ["Main Menu", CollectionHelper.collection_name]

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
	queue_source = SavedQueueSource.from_collection(CollectionHelper.current_collection, CollectionHelper.collection_type)
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

## Quits and leaves the queue playing in the engine's daemon, which carries
## on without Songo. Songo5.sh sees it still running and leaves the playback
## suppressions to it. Quits normally if nothing is playing.
func quit_songo_with_music():
	if SongoPlayer.keep_playing_after_exit() && queue_source != null:
		queue_source.save()
	else:
		SavedQueueSource.clear_saved()
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
	if target_container != null && target_container[0] is CollectionBuildRequest:
		content_body_node.remove_child(active_container)
		await _build_from_request(target_container[0])
	elif target_container != null && target_container[0] is MainMenuBuildRequest:
		content_body_node.remove_child(active_container)
		await _build_main_menu_from_request(target_container[0])
	elif target_container != null:
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

## Builds the page a CollectionBuildRequest stands in for and focuses its item.
## Expects the previous page to already be out of the tree.
func _build_from_request(request: CollectionBuildRequest) -> void:
	_open_collection(request.collection)
	var container = active_container
	finish_up_nav()
	# The list lays out its item pool on the first frame; focus after that.
	await get_tree().process_frame
	if active_container != container: return
	if skip_refocus:
		skip_refocus = false
	else:
		await container.virtualized_list.focus_index(request.focus_index)

## Builds the main menu a MainMenuBuildRequest stands in for and focuses its
## button. Expects the previous page to already be out of the tree.
func _build_main_menu_from_request(request: MainMenuBuildRequest) -> void:
	CollectionHelper.current_collection = null
	active_container = load(MAIN_MENU).instantiate()
	active_container.setup()
	nav_label = ["Main Menu"]
	var container = active_container
	finish_up_nav()
	# The theme builds its buttons and grabs its own focus over the first
	# frames, so ours goes in after that.
	await get_tree().process_frame
	await get_tree().process_frame
	if active_container != container: return
	if skip_refocus:
		skip_refocus = false
	else:
		_focus_button_for_action(container, request.focus_action)


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

# Untyped because the control can be freed by now, e.g. if the menu was rebuilt,
# and a typed parameter would reject it before the validity check runs.
func restore_focus(control):
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
	if stored_state == null:
		if SongoPlayer.is_playing(): await _rebuild_nav_to_playing_song()
		return
	
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
## `collection` (e.g. albums_index). Only the final list is built; the main menu
## and index page are left as build requests that nav_back builds with the right
## item focused. The final list lands on the playing song, or its first item.
## Leaving the song view follows the same rules as pressing back.
func rebuild_nav_to_collection(index_action: Callable, collection) -> void:
	if _rebuilding_nav: return
	_rebuilding_nav = true
	SfxPlayer.play_accept_sfx()

	var song_view = active_container if is_song_view(active_container) else null
	var keep_song_view = song_view != null && SongoPlayer.is_playing() && songo_settings.song_following
	# Grab the song view's focus (e.g. play/pause) before detaching it, so
	# returning via song follow restores it like a normal back press would.
	var song_view_focus = null
	if keep_song_view:
		var focused = get_viewport().gui_get_focus_owner()
		if focused != null && song_view.is_ancestor_of(focused): song_view_focus = focused
	if song_view != null && not keep_song_view:
		SongoPlayer.stop()

	# Keep the song view around for song following.
	_discard_nav_history(song_view if keep_song_view else null)

	# The main menu and index page go into history as build requests, so only
	# the end page is built and nothing else flashes up on the way. Empty
	# collections bail with an app message like collection_list() does: an empty
	# index lands on the main menu, and an empty target on the index page.
	# A null `collection` makes the index page itself the end page.
	var main_menu_request = MainMenuBuildRequest.new(index_action)
	var index_collection = _index_collection_for(index_action)
	if not _can_open_collection(index_collection):
		await _build_main_menu_from_request(main_menu_request)
	else:
		container_history.append([main_menu_request, null, null])
		var index_request = CollectionBuildRequest.new(index_collection, index_collection.find(collection))
		if collection == null:
			await _open_rebuilt_end_page(index_collection, keep_song_view)
		elif _can_open_collection(collection):
			container_history.append([index_request, null, null])
			await _open_rebuilt_end_page(collection, keep_song_view)
		else:
			await _build_from_request(index_request)

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

## The last page of rebuild_nav_to_collection(), landing on the playing song.
## `swap_queue` points the player's queue at this list too.
func _open_rebuilt_end_page(collection, swap_queue: bool) -> void:
	_open_collection(collection)
	finish_up_nav()
	await get_tree().process_frame
	var container = active_container
	if not is_song_list(container): return
	# Land on the playing song if it's in this list, otherwise the top.
	var playing_index = _current_song_index_in(container.list_items) if SongoPlayer.is_playing() else -1
	if playing_index >= 0:
		await container.virtualized_list.focus_index(playing_index)
	else:
		container.virtualized_list.focus_first()
	if swap_queue && _swap_player_queue_to(container.list_items):
		queue_source = SavedQueueSource.from_collection(collection, CollectionHelper.collection_type)

## Detaches and frees everything the navigation history references, except
## `keep`, and leaves it empty with no active page.
func _discard_nav_history(keep: Node = null) -> void:
	var stale = [active_container]
	for entry in container_history: stale.append(entry[0])
	if stored_state != null:
		stale.append(stored_state["active_container"])
		for entry in stored_state["container_history"]: stale.append(entry[0])
	if is_instance_valid(active_container) && active_container.is_inside_tree():
		content_body_node.remove_child(active_container)
	for container in stale:
		# Skips build requests, which are RefCounted and free themselves.
		if is_instance_valid(container) && container is Node && container != keep:
			container.queue_free()

	active_container = null
	container_history = []
	stored_state = null
	nav_label = []
	get_viewport().gui_release_focus()

## Fakes the history path to the song view for the playing song, through the
## list its queue was picked from (queue_source), e.g. Main Menu > Playlists >
## playlist > song view. Falls back to the song's album when that list is
## unknown or no longer holds the song. Used when there's no saved song view to
## return to, e.g. after booting into music left playing by "Quit with Music".
## Only the song view is built; every page under it is a build request that
## nav_back builds on the way out. The player's queue is left alone.
func _rebuild_nav_to_playing_song() -> void:
	if _rebuilding_nav: return
	var record = SongoPlayer.get_current_music_record()
	if record == null: return
	var source = queue_source.resolve(songo_data, record) if queue_source != null else null
	var index_action = queue_source.index_action() if source != null else albums_index
	if source == null: source = _album_for_record(record)
	if source == null: return

	SfxPlayer.play_accept_sfx()
	_discard_nav_history()

	var source_records = source if source is Array else source.music_records
	container_history.append([MainMenuBuildRequest.new(index_action), null, null])
	# All Songs is its own index page, so there's no list between it and the menu.
	if index_action != songs_index:
		var index_collection = _index_collection_for(index_action)
		container_history.append([CollectionBuildRequest.new(index_collection, index_collection.find(source)), null, null])
	container_history.append([CollectionBuildRequest.new(source, _current_song_index_in(source_records)), null, null])

	# Matches what songs_panel() leaves behind when picking a song from `source`.
	CollectionHelper.current_collection = source
	_set_nav_label_for_current_collection()
	active_container = load(SONG_PANEL_CONTAINER).instantiate()
	active_container.setup()
	finish_up_nav()

# The album holding `record`, preferring the one named in its tags when the same
# file shows up on more than one, or null.
func _album_for_record(record):
	var fallback = null
	for album in songo_data.albums:
		for album_record in album.music_records:
			if album_record.full_path == record.full_path:
				if album.name == record.album: return album
				if fallback == null: fallback = album
				break
	return fallback

# Points the player's queue at `music_records` (in list order) without
# interrupting playback. Skipped if the current song isn't in the list, e.g. the
# track changed while the info panel was open. True if it swapped.
func _swap_player_queue_to(music_records) -> bool:
	var index = _current_song_index_in(music_records)
	if index < 0: return false
	SongoPlayer.swap_music_records_silently(music_records, index)
	return true

# Index of the player's current song in `music_records`, matched by path, or -1.
func _current_song_index_in(music_records) -> int:
	var current = SongoPlayer.get_current_music_record()
	if current == null: return -1
	for i in range(music_records.size()):
		if music_records[i].full_path == current.full_path: return i
	return -1

## The list a main menu index action opens, matching what the action passes to
## collection_list().
func _index_collection_for(index_action: Callable):
	if index_action == albums_index: return songo_data.albums
	if index_action == artists_index: return songo_data.artists
	if index_action == playlists_index: return songo_data.playlists
	if index_action == settings_index: return settings_collection
	return songo_data.music_records

func _focus_button_for_action(node: Node, action: Callable) -> bool:
	if node is BaseButton && node.is_visible_in_tree() && node.pressed.is_connected(action):
		node.grab_focus()
		return true
	for child in node.get_children():
		if _focus_button_for_action(child, action): return true
	return false
