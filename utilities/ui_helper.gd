extends Node

var dark_out: Control
var app_message: Control
var main_color_panel: Control
var mini_song_panel: Control
var content_body: Control
var keyboard: Control
var flash_message_box: Control
var current_os_time: Control
#var debug_info: Control
var songo_settings = SongoSettings.get_instance()

var focus_chain = []
var original_size = null

func register_focus_change(item: Control):
	focus_chain.append(item)
	if focus_chain.size() > 2: focus_chain.remove_at(0)

func flash_message(message):
	flash_message_box.add_message(message)
	
func focus_back():
	if is_instance_valid(focus_chain[0]): focus_chain[0].grab_focus()
	
func apply_theme_color(color):
	var style = main_color_panel.get_theme_stylebox("panel").duplicate()
	style.bg_color = color
	main_color_panel.add_theme_stylebox_override("panel", style)
	
func apply_scale(new_scale: float):
	var window = get_tree().get_root().get_window()
	window.content_scale_factor = new_scale

#func apply_screen_fit():
#	var root = get_node("/root")
#	if original_size == null: original_size = root.size
#	root.size = DisplayServer.screen_get_size()
#	DisplayServer.window_set_size(original_size)
	
func show_mini_song_panel():
	if songo_settings.song_following:
		mini_song_panel.show()
	else:
		SongoPlayer.stop()
	
func hide_mini_song_panel():
	Controller.stored_state = null
	mini_song_panel.hide()
	
func dismiss_mini_song_panel():
	Controller.stored_state = null
	mini_song_panel.hide()
	SongoPlayer.stop()
	
func route_inputs(active_container, delta):
	if Input.is_action_just_pressed("start"):
		if mini_song_panel.visible:
			dismiss_mini_song_panel()
			return
	if Input.is_action_just_pressed("back"):
		if app_message.visible:
			app_message.dismiss()
			return
		if keyboard.visible:
			keyboard.dismiss()
			return
	if Input.is_action_just_pressed("select"):
		if mini_song_panel.visible:
			Controller.restore_state()
			
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
	
func get_time_string() -> String:
	var now = Time.get_datetime_dict_from_system()
	var hour_12 = now.hour % 12
	if hour_12 == 0: hour_12 = 12
	var hour = str(hour_12)
	if songo_settings.clock_24_hour: hour = now.hour
	var minute = str(now.minute).pad_zeros(2)
	return "%s:%s" % [hour, minute]

func update_os_time():
	if current_os_time: current_os_time.text = get_time_string()
