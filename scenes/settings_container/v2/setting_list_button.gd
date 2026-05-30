@tool
extends MarginContainer
signal pressed
signal focused
var content_component = null
const DEFAULT_SCENE_PATH = "res://internal_themes/SongoClassic/collection_button/collection_button.tscn"


@export var text: String = "Setting Title"
@export var hide_bottom_separator: bool = false
var _icon
@export var icon: Texture2D:
	set(value):
		if value == null: value = load("res://assets/gear.svg")
		_icon = value
		if Engine.is_editor_hint():
			%Button.icon = value
	get(): 
		if _icon: return _icon
		return load("res://assets/gear.svg")
		
var songo_settings

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Button.text = text
	%Button.icon = _icon
	$Button.pressed.connect(func():
		pressed.emit()
		)
	$Button.focus_entered.connect(func():
		focused.emit()
		)

		
func set_focus():
	$Button.grab_focus()

func _setup_button():
	if content_component != null:
		content_component.queue_free()
		content_component = null
		await Engine.get_main_loop().process_frame

	var scene_path = ThemeManager.get_scene_path('collection_button')
	if not scene_path:
		scene_path = DEFAULT_SCENE_PATH
			
	content_component = load(scene_path).instantiate()
	add_child(content_component)
	if hide_bottom_separator && "setup_last_item" in content_component:
		content_component.setup_last_item()
	
func _on_button_mouse_entered() -> void:
	%Button.grab_focus()


func _on_tree_entered() -> void:
	_setup_button()
