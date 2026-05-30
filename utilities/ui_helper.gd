extends Node

var dark_out: Control
var app_message: Control
var main_color_panel: Control
var content_body: Control
var content_margin_container: Control
var keyboard: Control
var flash_message_box: Control
#var debug_info: Control
var songo_settings = SongoSettings.get_instance()
var vol_container: Control
var crt_overlay: Control
var the_grid_overlay: Control

var focus_chain = []
var original_size = null

func register_focus_change(item: Control):
	focus_chain.append(item)
	if focus_chain.size() > 2: focus_chain.remove_at(0)

func flash_message(message):
	flash_message_box.add_message(message)
	
func focus_back():
	if is_instance_valid(focus_chain[0]): focus_chain[0].grab_focus()
	
func apply_scale(new_scale: float):
	var window = get_tree().get_root().get_window()
	window.content_scale_factor = new_scale
	
func apply_content_margin(new_margin: int):
	UiHelper.content_margin_container.add_theme_constant_override("margin_left", new_margin)
	UiHelper.content_margin_container.add_theme_constant_override("margin_right", new_margin)

	

#func apply_screen_fit():
#	var root = get_node("/root")
#	if original_size == null: original_size = root.size
#	root.size = DisplayServer.screen_get_size()
#	DisplayServer.window_set_size(original_size)
	
	
func route_inputs(active_container, delta):
	if Input.is_action_just_pressed("back"):
		if app_message.visible:
			app_message.dismiss()
			return
		if keyboard.visible:
			keyboard.dismiss()
			return
			
	if is_instance_valid(active_container): active_container.handle_input(delta)

func fire_focus_next():
	# Create a new InputEventKey
	var event = InputEventKey.new()
	# Set the key to Tab
	event.keycode = KEY_TAB
	# Set the event as pressed
	event.pressed = true
	# Set the event as a physical key press (often needed for proper handling)
	event.physical_keycode = KEY_TAB

	# Send the event to the engine's input processing
	Input.parse_input_event(event)

	# Optionally, release the key immediately to avoid continuous focusing
	event.pressed = false
	Input.parse_input_event(event)
	
func apply_user_theme(user_theme: Theme) -> void:
	var my_base_theme = load("res://songo_base_theme.tres")
	var final_theme := my_base_theme.duplicate()
	print("GOT HERE THMEE?")
	for type in user_theme.get_type_list():
		
				# Copy variation inheritance
		var base_type := user_theme.get_type_variation_base(type)

		if base_type != "":
			final_theme.set_type_variation(
				type,
				base_type
			)
		# StyleBoxes
		for name in user_theme.get_stylebox_list(type):
			print(name)
			final_theme.set_stylebox(
				name,
				type,
				user_theme.get_stylebox(name, type)
			)

		# Colors
		for name in user_theme.get_color_list(type):
			final_theme.set_color(
				name,
				type,
				user_theme.get_color(name, type)
			)

		# Constants
		for name in user_theme.get_constant_list(type):
			final_theme.set_constant(
				name,
				type,
				user_theme.get_constant(name, type)
			)

		# Fonts
		for name in user_theme.get_font_list(type):
			final_theme.set_font(
				name,
				type,
				user_theme.get_font(name, type)
			)

	get_tree().root.theme = final_theme
