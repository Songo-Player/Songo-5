extends Node
class_name DeviceOsStrategy

var music_dir_tip: String: get = get_music_dir_tip
var can_fade_screen: bool
var strategy_name:
	get: return get_script().get_global_name()

static var songo_data = SongoDataResource.get_instance()

static func being_used() -> bool:
	print("Implement me in child");
	return false
	
#func _init():
	#create_reset_script()
	
func get_music_dir_tip():
	return ""
	
func create_reset_script(commands: Array):
	var reset_path = "user://reset_values.sh"
	var reset_script = "#!/bin/sh\n"
	
	for command in commands:
		reset_script += command + "\n"
		
	reset_script += "echo SongoResetActive\n"
	var file = FileAccess.open(reset_path, FileAccess.WRITE)
	
	if file == null:
		print("Error opening file: ", FileAccess.get_open_error())
		return
		
	file.store_string(reset_script)
	file.close()
	
	# Make it executable
	OS.execute("chmod", ["+x", ProjectSettings.globalize_path(reset_path)])
	
var initial_delay := 0.5   # seconds to wait before first repeat
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
