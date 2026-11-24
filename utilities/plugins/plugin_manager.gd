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

# Android only: an Android app has no folder beside it for songo_plugins, so the
# devkit's Android release carries the packaged plugins in the APK as plain
# files under bundled_plugins/ (never in the main pck), with a manifest.json of
# each one's plugin.pck SHA-256. _install_bundled_plugins copies them into
# USER_PLUGINS_DIR, where they're loaded, updated and deleted like any other
# external plugin. No other build has bundled_plugins/.
const BUNDLED_PLUGINS_DIR = "res://bundled_plugins"
# What _install_bundled_plugins last did: the manifest it applied, the SHA-256
# each plugin was installed with, and the bundled plugins the user deleted
const BUNDLED_STATE_PATH = "user://bundled_plugins_state.json"

var plugins: Array[SongoPlugin] = []

## Every plugin found at boot, loaded or not, for Plugin Management. Keyed by
## plugin name, in discovery order. Each entry:
##   name, info (plugin.json), dir (where it was found),
##   from_source (true when loaded straight from plugins_raw in the editor),
##   instance (the SongoPlugin, or null if disabled / it failed to load),
##   settings_scene (res:// path of its settings page, or "")
var discovered := {}

var _songo_settings = SongoSettings.get_instance()

## Finds every installed plugin, then loads the enabled ones. Plugins are
## disabled until they're enabled from Plugin Management.
func load_plugins() -> void:
	_install_bundled_plugins()
	for plugin_dir in get_plugin_dirs():
		_discover_plugin(plugin_dir)
	for entry in discovered.values():
		if is_enabled(entry.name):
			_instantiate_plugin(entry)
		else:
			print("PluginManager: %s is disabled, not loading it" % entry.name)
	plugins_loaded.emit()

func is_enabled(plugin_name: String) -> bool:
	return _songo_settings.enabled_plugins.has(plugin_name)

## Enabling loads the plugin right away. Disabling takes effect on the next
## launch, since a running plugin can't be unloaded. Returns "" on success,
## otherwise what went wrong (the plugin stays enabled, and loading is tried
## again on the next launch).
func set_enabled(plugin_name: String, enabled: bool) -> String:
	if enabled:
		if not _songo_settings.enabled_plugins.has(plugin_name):
			_songo_settings.enabled_plugins.append(plugin_name)
	else:
		_songo_settings.enabled_plugins.erase(plugin_name)
	_songo_settings.save()
	if not enabled: return ""
	var entry: Dictionary = discovered.get(plugin_name, {})
	# Already running: it was disabled earlier this launch and is still loaded
	if entry.is_empty() or entry.instance != null: return ""
	if not _instantiate_plugin(entry):
		return "Couldn't load %s" % plugin_name
	return ""

## Whether it's been disabled but is still running until the next launch.
func needs_restart(plugin_name: String) -> bool:
	var entry: Dictionary = discovered.get(plugin_name, {})
	if entry.is_empty(): return false
	return entry.instance != null and not is_enabled(plugin_name)

func can_delete(plugin_name: String) -> bool:
	var entry: Dictionary = discovered.get(plugin_name, {})
	return not entry.is_empty() and not entry.from_source

## Deletes the plugin's folder. A loaded plugin keeps running until the next
## launch. Returns "" on success, otherwise what went wrong.
func delete_plugin(plugin_name: String) -> String:
	if not can_delete(plugin_name): return "This plugin can't be deleted"
	var dir: String = ProjectSettings.globalize_path(discovered[plugin_name].dir)
	var err := _remove_tree(dir)
	if err != OK: return "Couldn't delete the plugin (%s)" % error_string(err)
	_note_bundled_plugin_deleted(discovered[plugin_name].dir)
	discovered.erase(plugin_name)
	_songo_settings.enabled_plugins.erase(plugin_name)
	_songo_settings.save()
	return ""

# Android: copies the APK's bundled plugins into USER_PLUGINS_DIR. Only does
# anything when this APK's manifest differs from the last one applied, so
# normal launches just read two small files. For each bundled plugin:
# - one the user deleted (see _note_bundled_plugin_deleted) stays deleted
# - a copy that isn't the one this installed (the user replaced or updated it
#   themselves) is left alone
# - otherwise it's installed, or updated to the APK's version
func _install_bundled_plugins() -> void:
	if not OS.has_feature("android"): return
	var manifest := _read_json(BUNDLED_PLUGINS_DIR.path_join("manifest.json"))
	var bundled: Dictionary = manifest.get("plugins", {})
	if bundled.is_empty(): return
	var state := _read_json(BUNDLED_STATE_PATH)
	if JSON.stringify(state.get("manifest", {})) == JSON.stringify(bundled): return

	var installed: Dictionary = state.get("installed", {})
	var removed: Array = state.get("removed", [])
	for folder in bundled:
		var sha: String = bundled[folder]
		if removed.has(folder): continue
		var dest_pck := USER_PLUGINS_DIR.path_join(folder).path_join("plugin.pck")
		if FileAccess.file_exists(dest_pck):
			var current := FileAccess.get_sha256(dest_pck)
			if current == sha:
				installed[folder] = sha
				continue
			if current != installed.get(folder, ""):
				print("PluginManager: keeping %s, it isn't the bundled copy" % folder)
				continue
		if _copy_bundled_plugin(folder):
			installed[folder] = sha
			print("PluginManager: installed bundled plugin %s" % folder)
	_write_json(BUNDLED_STATE_PATH, {"manifest": bundled, "installed": installed, "removed": removed})

# Copies one bundled plugin's plugin.json and plugin.pck into USER_PLUGINS_DIR.
# Each file is written beside its destination first and renamed over it, so a
# failed write never leaves a half-written plugin.pck to load.
func _copy_bundled_plugin(folder: String) -> bool:
	var dest := USER_PLUGINS_DIR.path_join(folder)
	DirAccess.make_dir_recursive_absolute(dest)
	for file_name in ["plugin.json", "plugin.pck"]:
		var data := FileAccess.get_file_as_bytes(BUNDLED_PLUGINS_DIR.path_join(folder).path_join(file_name))
		if data.is_empty():
			push_error("PluginManager: bundled %s/%s is missing or empty" % [folder, file_name])
			return false
		var temp := dest.path_join(file_name + ".tmp")
		var file := FileAccess.open(temp, FileAccess.WRITE)
		if file == null:
			push_error("PluginManager: couldn't write %s (%s)" % [temp, error_string(FileAccess.get_open_error())])
			return false
		file.store_buffer(data)
		file.close()
		var err := DirAccess.rename_absolute(temp, dest.path_join(file_name))
		if err != OK:
			push_error("PluginManager: couldn't move %s into place (%s)" % [temp, error_string(err)])
			return false
	return true

# Remembers that the user deleted a plugin the APK installed, so updates don't
# bring it back. Does nothing outside Android, or for plugins it didn't install.
func _note_bundled_plugin_deleted(plugin_dir: String) -> void:
	if not OS.has_feature("android") or not plugin_dir.begins_with(USER_PLUGINS_DIR): return
	var state := _read_json(BUNDLED_STATE_PATH)
	var installed: Dictionary = state.get("installed", {})
	var folder := plugin_dir.get_file()
	if not installed.has(folder): return
	installed.erase(folder)
	var removed: Array = state.get("removed", [])
	if not removed.has(folder): removed.append(folder)
	state["installed"] = installed
	state["removed"] = removed
	_write_json(BUNDLED_STATE_PATH, state)

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var json = JSON.parse_string(FileAccess.get_file_as_string(path))
	return json if typeof(json) == TYPE_DICTIONARY else {}

func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("PluginManager: couldn't write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(data, "\t"))

func _remove_tree(path: String) -> Error:
	var dir := DirAccess.open(path)
	if dir == null: return DirAccess.get_open_error()
	for file in dir.get_files():
		var err := dir.remove(file)
		if err != OK: return err
	for sub_dir in dir.get_directories():
		var err := _remove_tree(path.path_join(sub_dir))
		if err != OK: return err
	return DirAccess.remove_absolute(path)

func get_plugin(plugin_name: String) -> SongoPlugin:
	for plugin in plugins:
		if plugin.plugin_name == plugin_name: return plugin
	return null

## Folders plugins are loaded from, in priority order (a plugin found in an
## earlier one wins over a copy with the same name in a later one).
func get_plugin_roots() -> Array[String]:
	var roots: Array[String] = []
	# Running from the editor, load plugins straight from their source so
	# edits don't need a repack. These win over packaged copies of the same name.
	if OS.has_feature("editor"):
		roots.append(RAW_PLUGINS_DIR)
	roots.append(USER_PLUGINS_DIR)
	var adjacent_dir := _find_adjacent_plugins_dir()
	if adjacent_dir != "":
		roots.append(adjacent_dir)
	return roots

## Where a user can put plugins, as full paths for showing in the UI. The
## songo_plugins folder next to Songo#5 is listed even if it doesn't exist yet.
func get_install_dirs() -> Array[String]:
	var dirs: Array[String] = []
	var adjacent_dir := _find_adjacent_plugins_dir()
	if adjacent_dir == "":
		adjacent_dir = OS.get_executable_path().get_base_dir().path_join(ADJACENT_PLUGINS_DIR_NAME)
	dirs.append(adjacent_dir)
	dirs.append(ProjectSettings.globalize_path(USER_PLUGINS_DIR))
	return dirs

func get_plugin_dirs() -> Array[String]:
	var dirs: Array[String] = []
	for root in get_plugin_roots():
		for sub_dir in list_dir(root, true):
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

func _discover_plugin(plugin_dir: String) -> void:
	var info := parse_plugin_json(plugin_dir)
	if info.is_empty():
		push_warning("PluginManager: no valid plugin.json in %s, skipping" % plugin_dir)
		return
	var plugin_name: String = info.get("name", plugin_dir.get_file())
	if discovered.has(plugin_name):
		print("PluginManager: %s already found, skipping %s" % [plugin_name, plugin_dir])
		return
	discovered[plugin_name] = {
		"name": plugin_name, "info": info, "dir": plugin_dir,
		"from_source": plugin_dir.begins_with(RAW_PLUGINS_DIR),
		"instance": null, "settings_scene": "",
	}

# Mounts a discovered plugin and starts it, at boot or when it's enabled while
# Songo is running. Returns whether it loaded.
func _instantiate_plugin(entry: Dictionary) -> bool:
	var plugin_name: String = entry.name
	var plugin_dir: String = entry.dir
	var info: Dictionary = entry.info
	var mount_path := plugin_dir
	if not plugin_dir.begins_with(RAW_PLUGINS_DIR):
		if not ProjectSettings.load_resource_pack(plugin_dir.path_join("plugin.pck")):
			push_error("PluginManager: failed to mount %s/plugin.pck" % plugin_dir)
			return false
		mount_path = RAW_PLUGINS_DIR.path_join(plugin_dir.get_file())

	var entry_path := mount_path.path_join(info.get("entry", DEFAULT_ENTRY))
	if not ResourceLoader.exists(entry_path):
		push_error("PluginManager: entry script not found at %s" % entry_path)
		return false
	var script = load(entry_path)
	var instance = script.new() if script is GDScript else null
	if not instance is SongoPlugin:
		push_error("PluginManager: %s does not extend SongoPlugin" % entry_path)
		if instance is Node: instance.free()
		return false

	instance.name = plugin_name.validate_node_name()
	instance.plugin_info = info
	instance.plugin_path = mount_path
	add_child(instance)
	plugins.append(instance)
	instance._plugin_ready()
	entry.instance = instance
	entry.settings_scene = _find_settings_scene(instance)
	print("PluginManager: loaded %s %s from %s" % [plugin_name, info.get("version", ""), plugin_dir])
	return true

# The plugin's own settings scene (plugin.json "settings_scene_path", relative
# to the plugin root), opened from Plugin Management. "" if it has none.
func _find_settings_scene(plugin: SongoPlugin) -> String:
	var scene_path: String = plugin.plugin_info.get("settings_scene_path", "")
	if scene_path.is_empty(): return ""
	if not scene_path.begins_with("res://"): scene_path = plugin.resolve_path(scene_path)
	if not ResourceLoader.exists(scene_path):
		push_error("PluginManager: settings scene for %s not found at %s" % [plugin.plugin_name, scene_path])
		return ""
	return scene_path
