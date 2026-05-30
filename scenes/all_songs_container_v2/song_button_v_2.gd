extends MarginContainer

var index
const DEFAULT_SCENE_PATH = "res://internal_themes/SongoClassic/collection_button/collection_button.tscn"
var content_component = null

func _ready():
	pass

func setup_last_item():
	# RYETODO: This needs to be fixed for themes
	if content_component && "setup_last_item" in content_component:
		content_component.setup_last_item()
		
func set_focus():
	%Button.grab_focus()

func setup(record, index_arg):
	if content_component == null:
		var scene_path = ThemeManager.get_scene_path('collection_button')
		if not scene_path:
			scene_path = DEFAULT_SCENE_PATH
			
		content_component = load(scene_path).instantiate()
		add_child(content_component)
		#await get_tree().process_frame
	if record is MusicRecord:
		content_component.setup_music_record(record)
	if record is AlbumRecord:
		content_component.setup_album_record(record)
	if record is ArtistRecord:
		content_component.setup_artist_record(record)
	if record is M3uCollection:
		content_component.setup_playlist_record(record)
	index = index_arg
	%Button.set_meta("item_index", index)

	if !%Button.pressed.is_connected(_song_button_pressed):
		%Button.pressed.connect(_song_button_pressed)
	
func _song_button_pressed():
	var current_page = Controller.active_container
	if current_page.list_items is Array[MusicRecord]:
		Controller.songs_panel(current_page.list_items, index)
	else: 
		Controller.collection_list(current_page.list_items[index])

func _on_button_mouse_entered() -> void:
	%Button.grab_focus()


func _on_button_focus_entered() -> void:
	CollectionHelper.target_item_index = index
	if content_component && "_on_button_focus_entered" in content_component:
		content_component._on_button_focus_entered()

func _on_button_focus_exited() -> void:
	if content_component && "_on_button_focus_exited" in content_component:
		content_component._on_button_focus_exited()
