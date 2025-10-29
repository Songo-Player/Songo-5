extends Node

var songo_data = SongoDataResource.get_instance()
var content_body_node
var nav_label_node
var active_container

var sfx_player
var songo_player
var history = []
var nav_label = []

const MAIN_MENU = "res://scenes/main_menu/main_menu.tscn"
const ALL_SONGS_CONTAINER = "res://scenes/all_songs_container/all_songs_container.tscn"
const SONG_PANEL_CONTAINER = "res://scenes/song_panel_container/song_panel_container.tscn"
const ALBUMS_CONTAINER = "res://scenes/albums_container/albums_container.tscn"
const SETTINGS_DIRECTORY_SELECT = "res://scenes/directory_container/directory_container.tscn"
const ARTISTS_CONTAINER = "res://scenes/artists_container/artists_container.tscn"
const SETTINGS_CONTAINER = "res://scenes/settings_container/settings_container.tscn"

func songs_index(music_records):
	if music_records.size() == 0: return
	append_history("songs_index", [music_records])
	clean_up_old_container()
	
	active_container = load(ALL_SONGS_CONTAINER).instantiate()
	active_container.setup(music_records, songo_player, sfx_player)
	nav_label = ["Main Menu", "All Songs"]
	finish_up_nav()
	
func album_songs_index(album):
	var music_records = album.music_records
	if music_records.size() == 0: return
	append_history("album_songs_index", [album])
	clean_up_old_container()
	
	active_container = load(ALL_SONGS_CONTAINER).instantiate()
	active_container.setup(music_records, songo_player, sfx_player)
	active_container.set_as_album(album)
	nav_label = ["Main Menu", "Albums", short_name(album.name, 30)]
	finish_up_nav()
	
func albums_index(albums):
	if albums.size() == 0: return
	append_history("albums_index", [albums])
	clean_up_old_container()
	
	active_container = load(ALBUMS_CONTAINER).instantiate()
	active_container.setup(albums)
	nav_label = ["Main Menu", "Albums"]
	finish_up_nav()
	
func artists_index(artists):
	if artists.size() == 0: return
	append_history("artists_index", [artists])
	clean_up_old_container()
	
	active_container = load(ARTISTS_CONTAINER).instantiate()
	active_container.setup(artists)
	nav_label = ["Main Menu", "Artists"]
	finish_up_nav()
	
func artist_songs_index(artist):
	var music_records = artist.music_records
	if music_records.size() == 0: return
	append_history("artist_songs_index", [artist])
	clean_up_old_container()
	
	active_container = load(ALL_SONGS_CONTAINER).instantiate()
	active_container.setup(music_records, songo_player, sfx_player)
	active_container.set_as_artist(artist)
	nav_label = ["Main Menu", "Artists", short_name(artist.name, 30)]
	finish_up_nav()
	
func songs_panel(music_records, play_index, play_type):
	nav_label = ["Main Menu", "All Songs", play_type]
	append_history("songs_panel", [music_records, play_index, play_type])
	if "album" in active_container && active_container.album != null:
		nav_label = ["Main Menu", "Albums", short_name(active_container.album.name, 20), play_type]
	if "artist" in active_container && active_container.artist != null:
		nav_label = ["Main Menu", "Artists", short_name(active_container.artist.name, 20), play_type]
		
	clean_up_old_container()

	active_container = load(SONG_PANEL_CONTAINER).instantiate()
	active_container.setup(songo_player)
	songo_player.play_index = play_index
	songo_player.music_files = music_records
	finish_up_nav()
	active_container.play()
	
func settings_directory_select():
	append_history("settings_directory_select", [])
	clean_up_old_container()
	
	active_container = load(SETTINGS_DIRECTORY_SELECT).instantiate()
	active_container.setup(content_body_node.get_node("DarkOut"))
	nav_label = ["Main Menu", "Settings", "Directories"]
	finish_up_nav()
	
func settings_index():
	append_history("settings_index", [])
	clean_up_old_container()
	
	active_container = load(SETTINGS_CONTAINER).instantiate()
	active_container.setup()
	nav_label = ["Main Menu", "Settings"]
	finish_up_nav()

func main_menu():
	append_history("main_menu", [])
	clean_up_old_container()
	active_container = load(MAIN_MENU).instantiate()
	active_container.setup()
	nav_label = ["Main Menu"]
	finish_up_nav()
	
func quit_songo():
	sfx_player.play_accept_sfx()
	content_body_node.get_node("DarkOut").show()
	content_body_node.get_node("ExitingOverlay").show()
	await get_tree().process_frame
	get_tree().quit()
	
##################################
#           HELPERS              #
##################################

func append_history(func_name: String, params: Array):
	var new_history = [func_name, params]
	if new_history in history: return
	sfx_player.play_accept_sfx()
	history.append(new_history)
	
func nav_back():
	sfx_player.play_back_sfx()
	if history.size() == 1: return
	history.remove_at(history.size()-1)
	var nav_target = history.back()
	callv(nav_target[0], nav_target[1])

func clean_up_old_container():
	if is_instance_valid(active_container):
		active_container.queue_free()

func finish_up_nav():
	content_body_node.add_child(active_container)
	nav_label_node.text = " > ".join(nav_label)

func short_name(name: String, limit: int):
	var shortened_name = name
	if name.length() > limit: shortened_name = name.left(limit-3)+"..."
	return shortened_name
