extends HBoxContainer
class_name LeftRightBtnContainer

# Expects exactly two Button (or BaseButton) children.
var _buttons: Array[BaseButton] = []
var _focus_overlays: Array[Panel] = []


func _ready() -> void:
	focus_mode = FOCUS_ALL
	for child in get_children():
		if child is BaseButton:
			_buttons.append(child)

	if _buttons.size() != 2:
		push_warning("%s expects exactly two BaseButton children, found %d." % [name, _buttons.size()])
		return

	if focus_mode == Control.FOCUS_NONE:
		push_warning("%s should have Focus Mode set to All/Click for this to work." % name)

	for button in _buttons:
		var overlay := Panel.new()
		overlay.name = "FocusOverlay"
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_theme_stylebox_override("panel", button.get_theme_stylebox("focus"))
		overlay.visible = false
		button.add_child(overlay)
		_focus_overlays.append(overlay)

	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)


func _input(event: InputEvent) -> void:
	if _buttons.size() != 2 or not has_focus():
		return

	if event.is_action_pressed("ui_left", false, true):
		_press(_buttons[0])
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right", false, true):
		_press(_buttons[1])
		get_viewport().set_input_as_handled()


func _press(button: BaseButton) -> void:
	if button.disabled:
		return
	button.pressed.emit()


func _on_focus_entered() -> void:
	for overlay in _focus_overlays:
		overlay.visible = true


func _on_focus_exited() -> void:
	for overlay in _focus_overlays:
		overlay.visible = false
