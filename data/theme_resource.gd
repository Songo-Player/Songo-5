extends Control
class_name ThemeResource

@export var theme_name: String
@export var theme_version: String

@export var background_root: Control

var settings
var settings_info
var settings_path: 
	get: return get_settings_path()

func get_settings_path():
	return ProjectSettings.globalize_path("user://theme-%s-%s.json" % [theme_name, theme_version])
	
	
func setup_theme_settings(settings_info_map):
	settings = load_theme_settings()	
	settings_info = settings_info_map
	if settings == {}:
		settings = build_from_defaults(settings_info_map)
		save_theme_settings()
		print("Creating theme settings")
	else:
		print("Found theme settings")

func build_from_defaults(settings_info_map):
	var built_settings = {}
	for setting_key in settings_info_map.keys():
		built_settings[setting_key] = settings_info_map[setting_key]["default"]
	
	return built_settings
	
func load_theme_settings() -> Dictionary:
	var file := FileAccess.open(settings_path, FileAccess.READ)
	if file == null:
		return {}

	var json = JSON.parse_string(file.get_as_text())
	return json if typeof(json) == TYPE_DICTIONARY else {}
	
func save_theme_settings() -> void:
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(settings, "\t"))
	ThemeManager.refresh_theme()
