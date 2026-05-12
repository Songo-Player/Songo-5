extends PanelContainer

signal keyboard_result(string)

@export var keyboard_title = "Enter your value"
var caps_mode = false
var text = ""
var focus_back_target
var key_events_connected = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
			
func setup(new_keyboard_title, focus_back_target_arg):
	get_parent().move_child(self, -1)
	keyboard_title = new_keyboard_title
	focus_back_target = focus_back_target_arg
	UiHelper.dark_out.show()
	show()
	text=""
	update_display_text()
	%DeleteButton.grab_focus()
	%KeyboardTitle.text = keyboard_title
	get_tree().paused = true
	
	if key_events_connected: return
	
	for key in [%DeleteButton, %EnterButton, %CapsButton, %SpaceButton]:
		key.mouse_entered.connect(func(): key.grab_focus())
		
	var char_keys = get_tree().get_nodes_in_group("characterKey")
	for key in char_keys:
		key.mouse_entered.connect(func(): key.grab_focus())
		key.pressed.connect(func(): 
			text = "%s%s" % [text, key.text]
			update_display_text()
		)
	key_events_connected = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	#if visible && Input.is_action_just_pressed("ui_accept"):
	#	var focused = get_viewport().gui_get_focus_owner()
	#	if focused.is_in_group("characterKey"):
	#		text = "%s%s" % [text, focused.text]
	#		update_display_text()

func update_mode():
	var char_keys = get_tree().get_nodes_in_group("characterKey")
	for char_key in char_keys:
		if caps_mode:
			char_key.text = char_key.text.to_upper()
		else:
			char_key.text = char_key.text.to_lower()
			
func dismiss():
	hide()
	UiHelper.dark_out.hide()
	if focus_back_target != null:
		focus_back_target.grab_focus()
	get_tree().paused = false
	
func update_display_text():
	text = text.replace("\n", "").replace("\r", "")
	%KeyboardText.text = text
	%KeyboardText.caret_column = text.length()
	if caps_mode:
		caps_mode = false
		update_mode()

func _on_caps_button_pressed() -> void:
	caps_mode = not caps_mode
	update_mode()

func _on_delete_button_pressed() -> void:
	text = text.left(text.length() - 1)
	update_display_text()

func _on_space_button_pressed() -> void:
	text = text + " "
	update_display_text()

func _on_enter_button_pressed() -> void:
	keyboard_result.emit(text)
	dismiss()
