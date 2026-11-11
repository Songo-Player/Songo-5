extends Node

signal theme_updated
signal theme_settings_updated
var current_theme
var theme_path
var default_theme_path = "res://internal_themes/SongoClassic"
var default_theme
const THEMABLE_COMPONENTS = ["main_menu", "background_root", "header", "main_song_view", "footer", "song_follow", "collection_button", "collection_header"]
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
	var file := FileAccess.open(theme_path_arg+"/theme.json", FileAccess.READ)
	if file == null: theme_path_arg = default_theme_path
	
	var theme_pck := ProjectSettings.load_resource_pack(theme_path_arg+"/theme.pck")
	if not theme_pck:
		push_error("Failed to mount theme pck")
	print("Got here? in theme pck")
		
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
		
	if current_theme.has("godot_theme_path"):
		var full_gd_theme_path = theme_path_arg + current_theme["godot_theme_path"]
		print(full_gd_theme_path)
		UiHelper.apply_user_theme(load(full_gd_theme_path))
	else:
		var base_theme = load("res://assets/songo_base_theme.tres")
		get_tree().root.theme = base_theme
		if UiHelper.transform_container:
			UiHelper.transform_container.theme = base_theme
	theme_updated.emit()
	
func get_scene_path(scene_name):
	if not current_theme:
		return false
	if not current_theme["components"].has(scene_name):
		return false

	if theme_path.begins_with("res://"):
		# Already project-relative — components live directly under theme_path.
		return "%s/%s" % [theme_path, _resolve_component_path(current_theme["components"][scene_name])]

	# theme_path is external (user://, an OS path, mounted SD path, etc).
	# The pck's internal mount root is derived from the theme's own directory
	# name, e.g. ".../external_themes/XBopRed" -> "XBopRed".
	var theme_dir_name = theme_path.get_file()
	return "res://theme_dev/themes_raw/%s/%s" % [theme_dir_name, _resolve_component_path(current_theme["components"][scene_name])]

# A component is usually a scene path, but can also let a setting choose between
# scenes: { "setting": "main_menu_layout", "scenes": { "b": "...", "c": "..." } }
# A saved value with no matching scene falls back to the setting's default.
func _resolve_component_path(component) -> String:
	if component is String:
		return component
	var setting_key: String = component["setting"]
	var selected = settings.get(setting_key)
	if not component["scenes"].has(selected):
		selected = settings_info[setting_key]["default"]
	return component["scenes"][selected]

# A setting can list "visible_when": { "other_setting": [allowed values] } to only
# show while every listed setting has one of its allowed values. A listed setting
# the current theme doesn't have is ignored, since it can't rule anything out.
func is_setting_visible(key: String) -> bool:
	var visible_when: Dictionary = settings_info[key].get("visible_when", {})
	for other_key in visible_when:
		if settings.has(other_key) and not settings[other_key] in visible_when[other_key]:
			return false
	return true

# The setting that a "visible_when" setting is displayed under, or "" if it has none.
# With several listed, this is the last one defined so it's shown below all of them.
func get_setting_parent(key: String) -> String:
	var visible_when: Dictionary = settings_info[key].get("visible_when", {})
	var parent := ""
	for other_key in settings_info:
		if other_key != key and visible_when.has(other_key) and settings.has(other_key):
			parent = other_key
	return parent

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
		_add_missing_settings(settings_info_map)

# Settings added to a theme since its settings file was saved would otherwise
# never appear, as the settings page only shows keys that were saved.
func _add_missing_settings(settings_info_map) -> void:
	var added := false
	var defaults = build_from_defaults(settings_info_map)
	for key in defaults:
		if not settings.has(key):
			settings[key] = defaults[key]
			added = true
	if added:
		save_theme_settings()

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
