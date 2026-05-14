extends Node

signal theme_updated
signal theme_settings_updated
var current_theme
var theme_path
var default_theme_path = "res://internal_themes/SongoClassic"
var default_theme
const THEMABLE_COMPONENTS = ["main_menu", "background_root", "header", "main_song_view", "footer"]
var settings = {}
var settings_info
var settings_path:
	get: return get_settings_path()

func get_settings_path():
	var name = current_theme["name"]
	var version = current_theme["version"]
	return ProjectSettings.globalize_path("user://theme-settings-%s-%s.json" % [name, version])

func set_current_theme(theme_path_arg):
	default_theme = parse_theme_json(default_theme_path)
	for conn in theme_settings_updated.get_connections():
		theme_settings_updated.disconnect(conn.callable)
		
	if theme_path_arg == "": return
	current_theme = parse_theme_json(theme_path_arg)
	theme_path = theme_path_arg
	if current_theme.has("settings"):
		setup_theme_settings(current_theme["settings"])
	else:
		settings = {}
		settings_info = {}
		
	theme_updated.emit()
	
func get_scene_path(scene_name):
	if current_theme:
		if current_theme["components"].has(scene_name):
			return "%s/%s" % [theme_path, current_theme["components"][scene_name]]
	return false
	
func refresh_theme():
	theme_settings_updated.emit()

func parse_theme_json(theme_dir_path):
	var file := FileAccess.open(theme_dir_path+"/theme.json", FileAccess.READ)
	if file == null:
		file = FileAccess.open("res://internal_themes/SongoClassic/theme.json", FileAccess.READ)
		#return {}

	var json = JSON.parse_string(file.get_as_text())
	return json if typeof(json) == TYPE_DICTIONARY else {}

func setup_theme_settings(settings_info_map):
	var mod_settings_info_map = settings_info_map.duplicate()
	settings = load_theme_settings()	
	mod_settings_info_map.merge(default_theme["settings"], true)
	settings_info = mod_settings_info_map
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
	
	var missing_components = THEMABLE_COMPONENTS.filter(func(item): return not item in current_theme["components"].keys())
	if missing_components.size() == 0:
		return built_settings
	
	for key in default_theme["settings"].keys():
		var default_dependents = default_theme["settings"][key]["dependents"]
		if arrays_share_element(default_dependents, missing_components):
			built_settings[key] = default_theme["settings"][key]["default"]
	
	return built_settings

func arrays_share_element(a: Array, b: Array) -> bool:
	for item in a:
		if item in b:
			return true
	return false
	
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
