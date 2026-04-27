@tool
extends MarginContainer
signal pressed
signal focused

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
	%ButtonSeparator.visible = not hide_bottom_separator
	$Button.pressed.connect(func():
		pressed.emit()
		)
	$Button.focus_entered.connect(func():
		focused.emit()
		)
	songo_settings = SongoSettings.get_instance()
	if songo_settings.theme_color == "fff":
		%TheTail.modulate = Color("444")
		
func set_focus():
	$Button.grab_focus()


func _on_button_mouse_entered() -> void:
	%Button.grab_focus()


func _on_the_tail_tree_entered() -> void:
	songo_settings = SongoSettings.get_instance()
	if songo_settings.theme_color == "fff":
		%TheTail.modulate = Color("444")
	else:
		%TheTail.modulate = Color("fff")
