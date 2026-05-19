extends Resource
class_name SongoSettings

# --- Constants ---
const SAVE_PATH := "user://songo_settings.tres"
const VERSION := "v0.3.0 Tina"
const SETTINGS_VERSION := "30Tina"

const SONG_SLEEP_TIMES = [1,5,10,15,30,45,60,120,300,99999]
const SONG_SLEEP_TYPES = ["Bright Fade", "Black Fade", "Disabled"]

const SEEK_TIMES = [5,10,15,25,30]

enum START_BEHAVIOR {LOCK, SLEEP, LOCK_SLEEP, KEEP_AWAKE}

# --- Generic Settings ---
@export var settings_version = ""

# --- UI Settings --- #
@export var ui_scale: float = 1.0
@export var content_margin: int = 16
@export var sfx_volume: float = 1.0
@export var music_volume: float = 1.0
#@export var theme_color_index = 0
#@export var clock_24_hour = false
#@export var main_menu_size = 1
@export var song_following = true
@export var ab_layout_swapped = false
@export var xy_layout_swapped = false
@export var seek_backward_time_index = 1
@export var seek_forward_time_index = 1
@export var lock_inputs_on_sleep = false

# --- Controls Settings --- #
@export var start_btn_behavior: START_BEHAVIOR = START_BEHAVIOR.LOCK

# --- Data Settings --- #
@export var auto_import: bool = true

# --- Advanced Settings --- #
@export var stream_buffer_length: int = 100

# --- CFW Settings --- #
@export var use_generic_strategy = false
@export var song_sleep_timer_index = 3 # 10s
@export var song_sleep_type = 0
@export var theme_path = "res://internal_themes/SongoClassic"

var song_sleep_timer:
	get: return SONG_SLEEP_TIMES[song_sleep_timer_index]
	
var song_sleep_type_name:
	get: return SONG_SLEEP_TYPES[song_sleep_type]
	
var seek_forward_time:
	get: return SEEK_TIMES[seek_forward_time_index]
	
var seek_backward_time:
	get: return SEEK_TIMES[seek_backward_time_index]

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
				print("Busting saved data")
		else:
			_instance = SongoSettings.new()
	return _instance

func save():
	print("Saving Settings")
	settings_version = SETTINGS_VERSION
	var error = ResourceSaver.save(self, SAVE_PATH)
	if error != OK:
		print("Error saving settings: ", error)
		return
		
