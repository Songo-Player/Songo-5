extends MarginContainer
class_name ThemeHeader

const DEFAULT_SCENE_PATH = "res://internal_themes/SongoClassic/header/header.tscn"
var theme_element: Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#_setup_from_theme()
	ThemeManager.theme_updated.connect(_setup_from_theme)

func _setup_from_theme():
	if not ThemeManager.current_theme: return
	var new_element: Control
	if theme_element:
		theme_element.queue_free()
		await get_tree().process_frame
	var theme_background_root_path = ThemeManager.get_scene_path('header')
	if theme_background_root_path:
		new_element = load(theme_background_root_path).instantiate()
	else:
		new_element = load(DEFAULT_SCENE_PATH).instantiate()
	theme_element = new_element
	add_child(new_element)
