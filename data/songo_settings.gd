extends Resource
class_name SongoSettings

# --- Constants ---
const SAVE_PATH := "user://songo_settings.tres"
const VERSION := "v0.3.0 Tina"
const SETTINGS_VERSION := "30Tina"

const SONG_SLEEP_TIMES = [1,5,10,15,30,45,60,120,300,99999]
const SONG_SLEEP_TYPES = ["Bright Fade", "Black Fade", "Disabled"]

const SEEK_TIMES = [5,10,15,25,30]

const TARGET_FPS_OPTIONS = [15, 30, 60, 120]

enum START_BEHAVIOR {LOCK, SLEEP, LOCK_SLEEP, KEEP_AWAKE}

# Remappable input action -> the setting holding its binding
const ACTION_BINDINGS = {
	"ui_accept": "confirm_binding",
	"back": "back_binding",
	"x": "shuffle_binding",
	"Y": "quick_menu_binding",
	"L1": "l1_binding",
	"R1": "r1_binding",
	"L2": "l2_binding",
	"R2": "r2_binding",
	"start": "start_binding",
	"select": "select_binding",
}

# Binding setting -> env var that overrides its default, e.g. SONGO_CTRL_ACCEPT=KEY_ENTER
const BINDING_ENV_VARS = {
	"confirm_binding": "SONGO_CTRL_ACCEPT",
	"back_binding": "SONGO_CTRL_BACK",
	"shuffle_binding": "SONGO_CTRL_SHUFFLE",
	"quick_menu_binding": "SONGO_CTRL_QUICK_MENU",
	"l1_binding": "SONGO_CTRL_L1",
	"r1_binding": "SONGO_CTRL_R1",
	"l2_binding": "SONGO_CTRL_L2",
	"r2_binding": "SONGO_CTRL_R2",
	"start_binding": "SONGO_CTRL_START",
	"select_binding": "SONGO_CTRL_SELECT",
}

# Indexed by JoyButton value
const JOY_BUTTON_NAMES = [
	"JOY_BUTTON_A", "JOY_BUTTON_B", "JOY_BUTTON_X", "JOY_BUTTON_Y",
	"JOY_BUTTON_BACK", "JOY_BUTTON_GUIDE", "JOY_BUTTON_START",
	"JOY_BUTTON_LEFT_STICK", "JOY_BUTTON_RIGHT_STICK",
	"JOY_BUTTON_LEFT_SHOULDER", "JOY_BUTTON_RIGHT_SHOULDER",
	"JOY_BUTTON_DPAD_UP", "JOY_BUTTON_DPAD_DOWN", "JOY_BUTTON_DPAD_LEFT", "JOY_BUTTON_DPAD_RIGHT",
	"JOY_BUTTON_MISC1", "JOY_BUTTON_PADDLE1", "JOY_BUTTON_PADDLE2", "JOY_BUTTON_PADDLE3",
	"JOY_BUTTON_PADDLE4", "JOY_BUTTON_TOUCHPAD",
]

# --- Generic Settings ---
@export var settings_version = ""

# --- UI Settings --- #
@export var ui_scale: float = 1.0
@export var content_margin: int = 16
@export var sfx_volume: float = 1.0
@export var music_volume: float = 1.0
@export var playback_blend_time: float = 4.0
@export var use_equalizer: bool = false
@export var equalizer: SongoEqualizer = SongoEqualizer.new()
@export var clock_24_hour: bool = true
#@export var theme_color_index = 0
#@export var main_menu_size = 1
@export var song_following = true
@export var scrape_lyrics = false
@export var render_lyrics = true
@export var seek_backward_time_index = 1
@export var seek_forward_time_index = 1
@export var lock_inputs_on_sleep = false
@export var rotate_display = false
@export var menu_visibility = {
	"all_songs": true,
	"albums": true,
	"artists": true,
	"playlists": true
}

# --- Controls Settings --- #
@export var start_btn_behavior: START_BEHAVIOR = START_BEHAVIOR.LOCK
@export var enable_stick_nav: bool = false
# Joypad button/trigger or key event bound to each remappable action
@export var confirm_binding: InputEvent = joy_binding(JOY_BUTTON_A)
@export var back_binding: InputEvent = joy_binding(JOY_BUTTON_B)
@export var shuffle_binding: InputEvent = joy_binding(JOY_BUTTON_X)
@export var quick_menu_binding: InputEvent = joy_binding(JOY_BUTTON_Y)
@export var l1_binding: InputEvent = joy_binding(JOY_BUTTON_LEFT_SHOULDER)
@export var r1_binding: InputEvent = joy_binding(JOY_BUTTON_RIGHT_SHOULDER)
@export var l2_binding: InputEvent = axis_binding(JOY_AXIS_TRIGGER_LEFT)
@export var r2_binding: InputEvent = axis_binding(JOY_AXIS_TRIGGER_RIGHT)
@export var start_binding: InputEvent = joy_binding(JOY_BUTTON_START)
@export var select_binding: InputEvent = joy_binding(JOY_BUTTON_BACK)

# --- Data Settings --- #
@export var auto_import: bool = true

# --- Advanced Settings --- #
# The music engine's output buffer, see SongoPlayer.set_buffer_length_ms
@export var stream_buffer_length: int = 100

# --- CFW Settings --- #
@export var use_generic_strategy = false
@export var song_sleep_timer_index = 3 # 10s
@export var song_sleep_type = 0
@export var theme_path = "res://internal_themes/SongoClassic"
@export var target_fps_index = 2 # 60fps

var song_sleep_timer:
	get: return SONG_SLEEP_TIMES[song_sleep_timer_index]

var target_fps:
	get: return TARGET_FPS_OPTIONS[target_fps_index]
	
var song_sleep_type_name:
	get: return SONG_SLEEP_TYPES[song_sleep_type]
	
var seek_forward_time:
	get: return SEEK_TIMES[seek_forward_time_index]
	
var seek_backward_time:
	get: return SEEK_TIMES[seek_backward_time_index]

var formatted_time:
	get: return _get_formatted_time()

func _get_formatted_time() -> String:
	var now = Time.get_datetime_dict_from_system()
	var hour_12 = now.hour % 12
	if hour_12 == 0: hour_12 = 12
	var hour = str(hour_12)
	if clock_24_hour: hour = str(now.hour)
	var minute = str(now.minute).pad_zeros(2)
	return "%s:%s" % [hour, minute]

# --- Internal static reference (optional safety) ---
static var _instance: SongoSettings = null

func _init():
	if _instance != null and _instance != self:
		push_error("SongoSettings is a singleton! Use SongoSettings.get_instance() instead of creating new instances.")
		return
		
static func get_instance() -> SongoSettings:
	if _instance == null:
		if ResourceLoader.exists(SAVE_PATH):
			_instance = ResourceLoader.load(SAVE_PATH)
			if _instance == null || _instance.settings_version != SETTINGS_VERSION:
				_instance = SongoSettings.new()
				_instance._apply_first_time_defaults()
				print("Busting saved data")
		else:
			_instance = SongoSettings.new()
			_instance._apply_first_time_defaults()
	return _instance

func reset_action_bindings():
	var defaults := default_bindings()
	for property in defaults:
		set(property, defaults[property])

# True when any binding differs from default_bindings()
func has_custom_bindings() -> bool:
	var defaults := default_bindings()
	for property in defaults:
		if not get(property).is_match(defaults[property]): return true
	return false

# Binding setting -> default event, including device specific SONGO_CTRL_* overrides
static func default_bindings() -> Dictionary:
	var defaults := {
		"confirm_binding": joy_binding(JOY_BUTTON_A),
		"back_binding": joy_binding(JOY_BUTTON_B),
		"shuffle_binding": joy_binding(JOY_BUTTON_X),
		"quick_menu_binding": joy_binding(JOY_BUTTON_Y),
		"l1_binding": joy_binding(JOY_BUTTON_LEFT_SHOULDER),
		"r1_binding": joy_binding(JOY_BUTTON_RIGHT_SHOULDER),
		"l2_binding": axis_binding(JOY_AXIS_TRIGGER_LEFT),
		"r2_binding": axis_binding(JOY_AXIS_TRIGGER_RIGHT),
		"start_binding": joy_binding(JOY_BUTTON_START),
		"select_binding": joy_binding(JOY_BUTTON_BACK),
	}
	for property in BINDING_ENV_VARS:
		var value := OS.get_environment(BINDING_ENV_VARS[property]).strip_edges()
		if value == "": continue
		var binding := parse_binding(value)
		if binding == null:
			push_warning("%s: unknown binding \"%s\"" % [BINDING_ENV_VARS[property], value])
			continue
		defaults[property] = binding
	return defaults

func _apply_first_time_defaults():
	reset_action_bindings()

# Display name of a binding, matching Godot's constant names (JOY_BUTTON_A, KEY_ENTER...)
static func binding_name(binding: InputEvent) -> String:
	if binding is InputEventJoypadButton:
		var button: int = binding.button_index
		if button >= 0 && button < JOY_BUTTON_NAMES.size():
			return JOY_BUTTON_NAMES[button]
		return "JOY_BUTTON_%s" % button
	if binding is InputEventJoypadMotion:
		match binding.axis:
			JOY_AXIS_TRIGGER_LEFT: return "JOY_AXIS_TRIGGER_LEFT"
			JOY_AXIS_TRIGGER_RIGHT: return "JOY_AXIS_TRIGGER_RIGHT"
		return "JOY_AXIS_%s" % binding.axis
	if binding is InputEventKey:
		var keycode: Key = binding.keycode if binding.keycode != KEY_NONE else binding.physical_keycode
		return "KEY_" + OS.get_keycode_string(keycode).to_upper().replace(" ", "_")
	return "NONE"

# Inverse of binding_name, null if the name isn't recognised
static func parse_binding(name: String) -> InputEvent:
	name = name.to_upper()
	if name.begins_with("JOY_BUTTON_"):
		var index := JOY_BUTTON_NAMES.find(name)
		if index != -1: return joy_binding(index as JoyButton)
		var number := name.trim_prefix("JOY_BUTTON_")
		if number.is_valid_int(): return joy_binding(number.to_int() as JoyButton)
	elif name.begins_with("JOY_AXIS_"):
		match name:
			"JOY_AXIS_TRIGGER_LEFT": return axis_binding(JOY_AXIS_TRIGGER_LEFT)
			"JOY_AXIS_TRIGGER_RIGHT": return axis_binding(JOY_AXIS_TRIGGER_RIGHT)
		var number := name.trim_prefix("JOY_AXIS_")
		if number.is_valid_int(): return axis_binding(number.to_int() as JoyAxis)
	elif name.begins_with("KEY_"):
		var key_name := name.trim_prefix("KEY_")
		# binding_name turns spaces into underscores (KEY_KP_ENTER), try both, and
		# Godot's own casing ("Kp Enter") in case the lookup is case sensitive
		var keycode := OS.find_keycode_from_string(key_name.replace("_", " "))
		if keycode == KEY_NONE: keycode = OS.find_keycode_from_string(key_name)
		if keycode == KEY_NONE: keycode = OS.find_keycode_from_string(key_name.capitalize())
		if keycode != KEY_NONE: return key_binding(keycode, keycode)
	return null

static func joy_binding(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	return event

static func axis_binding(axis: JoyAxis) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = 1.0
	return event

static func key_binding(keycode: Key, physical_keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.device = -1
	event.keycode = keycode
	event.physical_keycode = physical_keycode
	return event

func save():
	print("Saving Settings")
	settings_version = SETTINGS_VERSION
	var error = ResourceSaver.save(self, SAVE_PATH)
	if error != OK:
		print("Error saving settings: ", error)
		return
		
