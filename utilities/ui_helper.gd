extends Node

# Using this to decouple some tight crap in the main script
enum EVENT {TOGGLE_INFO}
signal ui_event(event: EVENT)

var darkout: Control
var app_message: Control
var content_body: Control
var content_margin_container: Control
var keyboard: Control
var flash_message_box: Control
var overlay_window: Window
var overlay_container: Control
var songo_settings = SongoSettings.get_instance()
var transform_container: Control

var focus_chain = []
## Msec from launch until the first main menu was drawn; -1 until then.
var boot_msec: int = -1
var original_size = null



func register_focus_change(item: Control):
	focus_chain.append(item)
	if focus_chain.size() > 2: focus_chain.remove_at(0)

func flash_message(message, persist_time: float = 3.0, type: FlashMessage.TYPE = FlashMessage.TYPE.NONE):
	flash_message_box.add_message(message, persist_time, type)
	
## Shows a panel over the whole UI in the overlay window, as the song info
## panel is shown, until close_overlay_panel(panel). See OverlayContainer.
func open_overlay_panel(panel: Control) -> void:
	overlay_container.open_panel(panel)

func close_overlay_panel(panel: Control) -> void:
	overlay_container.close_panel(panel)

## Closes whatever open_overlay_panel is showing, e.g. before switching themes.
func close_overlay_panels() -> void:
	overlay_container.close_current_panel()

func focus_back():
	if is_instance_valid(focus_chain[0]): focus_chain[0].grab_focus()
	
func apply_scale(new_scale: float):
	var window = get_tree().get_root().get_window()
	window.content_scale_factor = new_scale
	apply_rotation()
	
func apply_rotation():
	var degrees: int = posmod(songo_settings.display_rotation, 360)
	var root_node = transform_container.get_parent().get_parent()

	var window_size = get_viewport().get_visible_rect().size
	var scaled_size = window_size # * (1.0 / songo_settings.ui_scale)

	# Content size and offset (in the rotated parent's local space) so the
	# rotated container lands exactly on screen
	var content_size: Vector2 = scaled_size
	var offset := Vector2.ZERO
	match degrees:
		90:
			content_size = Vector2(scaled_size.y, scaled_size.x)
			offset = Vector2(0, -content_size.y)
		180:
			offset = -content_size
		270:
			content_size = Vector2(scaled_size.y, scaled_size.x)
			offset = Vector2(-content_size.x, 0)
		_:
			degrees = 0

	root_node.custom_minimum_size = content_size
	transform_container.size = content_size
	transform_container.position = offset
	transform_container.get_parent().rotation = deg_to_rad(degrees)

	
## Side margin that keeps a card spanning `area_size` no wider than it would be
## on a 4:3 screen of the same height. Overlay cards stretch too far otherwise
## on widescreen devices. Portrait and narrower areas just get `base_margin`.
func capped_card_side_margin(area_size: Vector2, base_margin: int) -> int:
	var max_width := area_size.y * 4.0 / 3.0
	return base_margin + int(maxf(0.0, (area_size.x - max_width) / 2.0))

func apply_content_margin(new_margin: int):
	content_margin_container.add_theme_constant_override("margin_left", new_margin)
	content_margin_container.add_theme_constant_override("margin_right", new_margin)

	
	
func route_inputs(active_container, delta):
	if Input.is_action_just_pressed("back"):
		if app_message.visible:
			app_message.dismiss()
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
	var my_base_theme = load("res://assets/songo_base_theme.tres")
	var final_theme := my_base_theme.duplicate()
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
	if transform_container:
		transform_container.theme = final_theme
	get_tree().root.theme = final_theme
