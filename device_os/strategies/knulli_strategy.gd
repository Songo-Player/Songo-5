extends DeviceOsStrategy
class_name KnulliStrategy

var target_brightness: int = 255

static func being_used() -> bool:
	return OS.get_environment("CFW_NAME") == DeviceOS.CFW_KNULLI
	
func _init():
	can_fade_screen = true
	set_knulli_config()
	set_target_brightness()
	
func get_music_dir_tip():
	return "Looks like you're using Knulli: Try starting in /userdata/music/"
	
########################################
#       Knulli strategy exclusives     #
########################################

func set_target_brightness():
	#var cmd =  "source %s && DISPLAY_READ lcd0 getbl" % FUNC_SCRIPT
	var output = []
	var exit_code = OS.execute("sh", ["-c", "brightness get"], output)
	var result = output[0].strip_edges() if output.size() > 0 else ""
	if result != "":
		target_brightness = int(result)
		
func set_knulli_config():
	var reset_commands = []
	set_input_actions()
	#swap_abxy()
	
	OS.execute("sh", ["-c", "touch /var/run/battery-saver/songo.pause"])
	reset_commands.append("rm /var/run/battery-saver/songo.pause")
	create_reset_script(reset_commands)
	
func swap_abxy():
	var b_event := InputEventKey.new()
	b_event.keycode = KEY_B
	
	var enter_event := InputEventKey.new()
	enter_event.keycode = KEY_ENTER
	
	var y_event := InputEventKey.new()
	y_event.keycode = KEY_Y
	
	var joypad_east_event := InputEventJoypadButton.new()
	joypad_east_event.button_index = JOY_BUTTON_B
	
	var joypad_south_event := InputEventJoypadButton.new()
	joypad_south_event.button_index = JOY_BUTTON_A

	# --- Wipe the relevant actions ---
	if InputMap.has_action("ui_accept"):
		InputMap.erase_action("ui_accept")
		InputMap.add_action("ui_accept")

	if InputMap.has_action("back"):
		InputMap.erase_action("back")
		InputMap.add_action("back")
		
	if InputMap.has_action("x"):
		InputMap.erase_action("x")
		InputMap.add_action("x")

	# --- Rebind swapped mappings ---
	# ui_accept and primary now use B
	InputMap.action_add_event("ui_accept", b_event)
	InputMap.action_add_event("ui_accept", joypad_south_event)
	# back now uses Enter
	InputMap.action_add_event("back", enter_event)
	InputMap.action_add_event("back", joypad_east_event)
	
	# x now uses y
	InputMap.action_add_event("x", y_event)
	
# Config
var initial_delay := 0.5   # seconds to wait before first repeat

# State
var timer := 0.0
var held_action := ""
var idle := true

func translate_inputs(delta):
	var action_name = ""
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP):
		action_name = "ui_up"
	elif Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN):
		action_name = "ui_down"

	if action_name == "":
		idle = true
		held_action = ""
		timer = 0.0
		return

	# First input after idle fires immediately
	if idle or held_action != action_name:
		held_action = action_name
		timer = 0.0
		idle = false
		return

	# Held input: wait initial delay, then fire every frame
	timer += delta
	if timer >= initial_delay:
		fake_input(action_name)
	
func fake_input(action_name):
	var a = InputEventAction.new()
	a.action = action_name
	a.pressed = true
	Input.parse_input_event(a)
	
	var b = InputEventAction.new()
	b.action = action_name
	b.pressed = false
	Input.parse_input_event(b)
	
	
func set_input_actions():
	var start_event = InputEventJoypadButton.new()
	start_event.button_index = JOY_BUTTON_START
	
	var east_event = InputEventJoypadButton.new()
	east_event.button_index = JOY_BUTTON_B
	var south_event = InputEventJoypadButton.new()
	south_event.button_index = JOY_BUTTON_A

	InputMap.action_add_event("ui_accept", east_event)
	InputMap.action_add_event("back", south_event)
	
	InputMap.action_add_event("start", start_event)
