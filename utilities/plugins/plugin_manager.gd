extends Node

## Discovers, mounts and instantiates plugins. Plugins are packaged the same
## way themes are (see plugin_dev/plugin_packer.gd): a folder holding a
## plugin.json and a plugin.pck whose contents mount at
## res://plugin_dev/plugins_raw/<folder name>/.

signal plugins_loaded

const USER_PLUGINS_DIR = "user://external_plugins"
const ADJACENT_PLUGINS_DIR_NAME = "songo_plugins"
const RAW_PLUGINS_DIR = "res://plugin_dev/plugins_raw"
const DEFAULT_ENTRY = "plugin.gd"

var plugins: Array[SongoPlugin] = []

func load_plugins() -> void:
	for plugin_dir in get_plugin_dirs():
		_load_plugin(plugin_dir)
	plugins_loaded.emit()

func get_plugin(plugin_name: String) -> SongoPlugin:
	for plugin in plugins:
		if plugin.plugin_name == plugin_name: return plugin
	return null

func get_plugin_dirs() -> Array[String]:
	var roots: Array[String] = []
	# Running from the editor, load plugins straight from their source so
	# edits don't need a repack. These win over packaged copies of the same name.
	if OS.has_feature("editor"):
		roots.append(RAW_PLUGINS_DIR)
	roots.append(USER_PLUGINS_DIR)
	var adjacent_dir := _find_adjacent_plugins_dir()
	if adjacent_dir != "":
		roots.append(adjacent_dir)

	var dirs: Array[String] = []
	for root in roots:
		for sub_dir in list_dir(root, true):
			# Dot-prefixed folders in songo_plugins are disabled/ignored plugins.
			if root == adjacent_dir && sub_dir.begins_with("."): continue
			dirs.append(root.path_join(sub_dir))
	return dirs

## Lists files (or dirs) at a path. Once any pck is mounted (e.g. an external
## theme), res:// listings only see packed content, so editor runs fall back to
## the project folder on disk for res:// paths. File loads aren't affected.
func list_dir(path: String, directories: bool = false) -> PackedStringArray:
	var entries := _list_dir(path, directories)
	if entries.is_empty() && path.begins_with("res://") && OS.has_feature("editor"):
		entries = _list_dir(ProjectSettings.globalize_path(path), directories)
	return entries

# DirAccess.open fails quietly on missing dirs, unlike get_files_at().
func _list_dir(path: String, directories: bool) -> PackedStringArray:
	var dir := DirAccess.open(path)
	if dir == null: return PackedStringArray()
	return dir.get_directories() if directories else dir.get_files()

# Same lookup as songo_themes: a songo_plugins folder next to the executable,
# or up to 3 levels above it.
func _find_adjacent_plugins_dir() -> String:
	var base := OS.get_executable_path().get_base_dir()
	for i in range(4):
		var candidate := base.path_join(ADJACENT_PLUGINS_DIR_NAME)
		if DirAccess.dir_exists_absolute(candidate):
			return candidate
		base = base.get_base_dir()
	return ""

func parse_plugin_json(plugin_dir: String) -> Dictionary:
	var file := FileAccess.open(plugin_dir.path_join("plugin.json"), FileAccess.READ)
	if file == null: return {}
	var json = JSON.parse_string(file.get_as_text())
	return json if typeof(json) == TYPE_DICTIONARY else {}

func _load_plugin(plugin_dir: String) -> void:
	var info := parse_plugin_json(plugin_dir)
	if info.is_empty():
		push_warning("PluginManager: no valid plugin.json in %s, skipping" % plugin_dir)
		return
	var plugin_name: String = info.get("name", plugin_dir.get_file())
	if get_plugin(plugin_name) != null:
		print("PluginManager: %s already loaded, skipping %s" % [plugin_name, plugin_dir])
		return

	var mount_path := plugin_dir
	if not plugin_dir.begins_with(RAW_PLUGINS_DIR):
		if not ProjectSettings.load_resource_pack(plugin_dir.path_join("plugin.pck")):
			push_error("PluginManager: failed to mount %s/plugin.pck" % plugin_dir)
			return
		mount_path = RAW_PLUGINS_DIR.path_join(plugin_dir.get_file())

	var entry_path := mount_path.path_join(info.get("entry", DEFAULT_ENTRY))
	if not ResourceLoader.exists(entry_path):
		push_error("PluginManager: entry script not found at %s" % entry_path)
		return
	var script = load(entry_path)
	var instance = script.new() if script is GDScript else null
	if not instance is SongoPlugin:
		push_error("PluginManager: %s does not extend SongoPlugin" % entry_path)
		if instance is Node: instance.free()
		return

	instance.name = plugin_name.validate_node_name()
	instance.plugin_info = info
	instance.plugin_path = mount_path
	add_child(instance)
	plugins.append(instance)
	instance._plugin_ready()
	_register_settings_page(instance)
	print("PluginManager: loaded %s %s from %s" % [plugin_name, info.get("version", ""), plugin_dir])

# Links the plugin's own settings scene (plugin.json "settings_scene_path",
# relative to the plugin root) from the Settings list, under the plugin's name.
func _register_settings_page(plugin: SongoPlugin) -> void:
	var scene_path: String = plugin.plugin_info.get("settings_scene_path", "")
	if scene_path.is_empty(): return
	if not scene_path.begins_with("res://"): scene_path = plugin.resolve_path(scene_path)
	if not ResourceLoader.exists(scene_path):
		push_error("PluginManager: settings scene for %s not found at %s" % [plugin.plugin_name, scene_path])
		return
	var record := SettingRecord.new(plugin.plugin_name, "", false)
	record.action = Controller.plugin_settings.bind(plugin, scene_path)
	Controller.add_settings_record(record)
