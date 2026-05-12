extends MarginContainer
class_name ThemeMainMenu

const DEFAULT_SCENE_PATH = "res://internal_themes/SongoClassic/main_menu/main_menu.tscn"
var theme_element: Control
var theme_path


func setup():
	pass

		
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_setup_from_theme()
	ThemeManager.theme_updated.connect(_tear_down_theme)
	if "setup" in theme_element:
		theme_element.setup()
		
func render_ui():
	pass
	
func handle_input(delta: float):
	pass
		
func _setup_from_theme():
	var new_element: Control
	if theme_element:
		theme_element.queue_free()
		await get_tree().process_frame
	var theme_component_path = ThemeManager.get_scene_path('main_menu')
	if theme_component_path:
		new_element = load(theme_component_path).instantiate()
	else:
		new_element = load(DEFAULT_SCENE_PATH).instantiate()
	theme_path = ThemeManager.theme_path
	theme_element = new_element
	add_child(new_element)

func _tear_down_theme():
	if theme_element:
		theme_element.queue_free()
		theme_element = null
	
func _on_tree_entered() -> void:
	if ThemeManager.theme_path != theme_path:
		_setup_from_theme()
