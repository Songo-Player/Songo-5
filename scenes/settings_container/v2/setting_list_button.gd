extends MarginContainer
signal pressed
signal focused

@export var text: String = "Setting Title"
@export var hide_bottom_separator: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Button.text = text
	%ButtonSeparator.visible = not hide_bottom_separator
	$Button.pressed.connect(func():
		pressed.emit()
		)
	$Button.focus_entered.connect(func():
		focused.emit()
		)
		
func set_focus():
	$Button.grab_focus()


func _on_button_mouse_entered() -> void:
	%Button.grab_focus()
