extends PanelContainer

signal keyboard_result(string)
# OverlayContainer listens to show/hide the overlay window and darkout.
signal shown_changed(shown: bool)

@export var keyboard_title = "Enter your value"
enum Mode { LOWERCASE, UPCASE, SYMBOLS }
# Assigned to character keys in scene order: top row, middle row, bottom row.
const SYMBOLS = [
	"1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
	"-", "!", "@", "#", "$", "%", "&", "(", ")",
	"'", "\"", ",", ".", "_", "/", ":",
]
var mode = Mode.LOWERCASE
var text = ""
var key_events_connected = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Lives in the overlay window, which has its own focus, so whatever was focused
# in the main UI keeps its focus and there's nothing to restore on dismiss.
func setup(new_keyboard_title):
	keyboard_title = new_keyboard_title
	show()
	shown_changed.emit(true)
	text=""
	update_display_text()
	%DeleteButton.grab_focus()
	%KeyboardTitle.text = keyboard_title
	mode = Mode.LOWERCASE
	update_mode()
	
	if key_events_connected: return
	
	for key in [%DeleteButton, %EnterButton, %ModeButton, %SpaceButton]:
		key.mouse_entered.connect(func(): key.grab_focus())
		
	for key in get_char_keys():
		key.set_meta("letter", key.text.strip_edges().to_lower())
		key.mouse_entered.connect(func(): key.grab_focus())
		key.pressed.connect(func(): 
			text = "%s%s" % [text, key.text]
			update_display_text()
		)
	key_events_connected = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	#if visible && Input.is_action_just_pressed("ui_accept"):
	#	var focused = get_viewport().gui_get_focus_owner()
	#	if focused.is_in_group("characterKey"):
	#		text = "%s%s" % [text, focused.text]
	#		update_display_text()

func get_char_keys() -> Array:
	return find_children("*", "Button", true, false).filter(
		func(node): return node.is_in_group("characterKey"))

func update_mode():
	var char_keys = get_char_keys()
	for i in char_keys.size():
		var char_key = char_keys[i]
		var letter: String = char_key.get_meta("letter", char_key.text.to_lower())
		match mode:
			Mode.LOWERCASE:
				char_key.text = letter
			Mode.UPCASE:
				char_key.text = letter.to_upper()
			Mode.SYMBOLS:
				char_key.text = SYMBOLS[i] if i < SYMBOLS.size() else letter

func dismiss():
	hide()
	shown_changed.emit(false)
	
func update_display_text():
	text = text.replace("\n", "").replace("\r", "")
	%KeyboardText.text = text
	%KeyboardText.caret_column = text.length()
	# Upcase only applies to the next key, like a shift.
	if mode == Mode.UPCASE:
		mode = Mode.LOWERCASE
		update_mode()

func _on_mode_button_pressed() -> void:
	mode = (mode + 1) % Mode.size()
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
