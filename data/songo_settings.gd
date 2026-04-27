extends Resource
class_name SongoSettings

# --- Constants ---
const SAVE_PATH := "user://songo_settings.tres"
const VERSION := "v0.3.0 Tina"
const SETTINGS_VERSION := "30Tina"

const SONG_SLEEP_TIMES = [1,5,10,15,30,45,60,99999]
const SONG_SLEEP_TYPES = ["Bright Fade", "Black Fade", "Disabled"]

const SEEK_TIMES = [5,10,15,25,30]

const THEME_COLOR_NAMES = [
	"Grayish Blue",
	"Purpley",
	"Emerald Green",
	"Purpley Blue",
	"Burnt Orange",
	"Another Blue",
	"Pumpkin Spice",
	"Voice Chat Color",
	"Red-bernic",
	"Pink?",
	"Oops! No color!",
	"Wrong Channel",
	"Boring...",
	"The Grid"
]

const THEME_COLORS = [
	"48486d", # Grayish Blue
	"84233b", # Purpley
	"215a30", # Emerald Green
	"562b90", # Purpley Blue
	"7c2a00", # Burnt Orange
	"004988", # Another Blue
	"d57200",  # Pumpkin Spice
	"5865F2", # Voice Chat Color
	"cc1111", # Red-bernic
	"FB6F92", # Pink?
	"777", # Oops! No Color
	"48486c", # Wrong Channel
	"fff", # Boring...
	"111" # The Grid
]

# --- Generic Settings ---
@export var settings_version = ""

# --- UI Settings --- #
@export var ui_scale: float = 1.0
@export var content_margin: int = 16
@export var sfx_volume: float = 1.0
@export var music_volume: float = 1.0
@export var theme_color_index = 0
@export var clock_24_hour = false
@export var main_menu_size = 1
@export var song_following = true
@export var ab_layout_swapped = false
@export var xy_layout_swapped = false
@export var seek_backward_time_index = 1
@export var seek_forward_time_index = 1
@export var lock_inputs_on_sleep = false
@export var main_menu_visible = {
	"all_songs": true,
	"albums": true,
	"artists": true,
	"playlists": true
}

# --- Data Settings --- #
@export var auto_import: bool = true

# --- Advanced Settings --- #
@export var stream_buffer_length: int = 100

# --- CFW Settings --- #
@export var use_generic_strategy = false
@export var song_sleep_timer_index = 3 # 10s
@export var song_sleep_type = 0

var theme_color: 
	get: return THEME_COLORS[theme_color_index]
	
var theme_color_name:
	get: return THEME_COLOR_NAMES[theme_color_index]
	
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
		
