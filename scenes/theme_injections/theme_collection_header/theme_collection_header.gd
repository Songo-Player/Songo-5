extends MarginContainer
class_name ThemeCollectionHeader

const DEFAULT_SCENE_PATH = "res://internal_themes/SongoClassic/collection_header/collection_header.tscn"
var theme_element: Control
var image_texture = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#_setup_from_theme()
	ThemeManager.theme_updated.connect(_setup_from_theme)

func _setup_from_theme():
	if not ThemeManager.current_theme: return
	var new_element: Control
	if theme_element:
		theme_element.queue_free()
		theme_element = null
		#await get_tree().process_frame
	var theme_element_path = ThemeManager.get_scene_path('collection_header')
	if theme_element_path:
		new_element = load(theme_element_path).instantiate()
	else:
		new_element = load(DEFAULT_SCENE_PATH).instantiate()
	theme_element = new_element
	add_child(new_element)
	
func setup(sort_key):
	if not is_instance_valid(theme_element): _setup_from_theme()
	theme_element.setup(sort_key)
