@tool
extends EditorScript

const PCK_ALIGNMENT := 32

# Kept so the script still runs standalone from the editor's "Run" button.
# Change this to pack a different plugin without a launcher script.
const PLUGIN_DIR_NAME := "WebRadio"

func _run() -> void:
	pack_plugin(PLUGIN_DIR_NAME)

func pack_plugin(plugin_dir_name: String) -> bool:
	var source_dir := "res://plugin_dev/plugins_raw/%s" % plugin_dir_name
	# Mount at the exact same path the plugin is authored at, same as themes.
	# PluginManager loads the entry script from this path once the pck is mounted.
	var pack_root := source_dir

	var plugin_json := source_dir.path_join("plugin.json")

	var output_dir = "res://plugin_dev/plugins_packaged/%s" % plugin_dir_name
	var pck_output: String = output_dir.path_join("plugin.pck")

	var external_dir := "user://external_plugins/%s" % plugin_dir_name

	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(source_dir)):
		push_error("Plugin source dir not found: %s" % source_dir)
		return false
	if not FileAccess.file_exists(plugin_json):
		push_error("Plugin has no plugin.json: %s" % plugin_json)
		return false

	var packer := PCKPacker.new()
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	if err != OK:
		push_error("Failed to create output dir %s: %s" % [output_dir, err])
		return false

	err = packer.pck_start(pck_output, PCK_ALIGNMENT)
	if err != OK:
		push_error("Failed to start pck: %s" % err)
		return false

	var added: Dictionary = {}
	var count := _add_dir(packer, source_dir, pack_root, added)

	err = packer.flush(true)
	if err != OK:
		push_error("Failed to flush pck: %s" % err)
		return false

	print("Packed %d files into %s" % [count, pck_output])

	_copy_to_dir(plugin_json, output_dir)

	# Mirror the packaged plugin into user://external_plugins so the packaged
	# load path can be exercised the same way external themes are.
	err = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(external_dir))
	if err != OK:
		push_error("Failed to create external plugins dir %s: %s" % [external_dir, err])
		return false

	_copy_to_dir(pck_output, external_dir)
	_copy_to_dir(plugin_json, external_dir)

	print("Mirrored plugin to %s" % external_dir)

	return true

func _copy_to_dir(source_path: String, dest_dir: String) -> void:
	if not FileAccess.file_exists(source_path):
		push_warning("File not found, skipping copy: %s" % source_path)
		return
	var dest_path := dest_dir.path_join(source_path.get_file())
	var err := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(dest_path)
	)
	if err != OK:
		push_error("Failed to copy %s to %s: %s" % [source_path, dest_path, err])
		return
	print("Copied %s to %s" % [source_path.get_file(), dest_path])

# dir_path: where we're currently reading from on disk (under source_dir)
# pack_root: where this same subtree should live inside the mounted pck
func _add_dir(packer: PCKPacker, dir_path: String, pack_root: String, added: Dictionary) -> int:
	var count := 0
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("Could not open dir: %s" % dir_path)
		return count
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name in [".", "..", ".godot"]:
			name = dir.get_next()
			continue
		var full_path := dir_path.path_join(name)
		var target_path := pack_root.path_join(name)
		if dir.current_is_dir():
			count += _add_dir(packer, full_path, target_path, added)
		else:
			count += _add_file(packer, full_path, target_path, added)
			if name.ends_with(".import"):
				count += _add_imported_targets(packer, full_path, added)
		name = dir.get_next()
	dir.list_dir_end()
	return count

func _add_file(packer: PCKPacker, source_path: String, target_path: String, added: Dictionary) -> int:
	if added.has(target_path):
		return 0
	var err := packer.add_file(target_path, source_path)
	if err != OK:
		push_warning("Failed to add %s (%s)" % [source_path, err])
		return 0
	added[target_path] = true
	return 1

# Imported assets (.import files) point at their real remapped resource under
# res://.godot/imported/..., so those are added under their own real path.
func _add_imported_targets(packer: PCKPacker, import_file_path: String, added: Dictionary) -> int:
	var count := 0
	var cfg := ConfigFile.new()
	if cfg.load(import_file_path) != OK:
		push_warning("Could not parse import file: %s" % import_file_path)
		return count
	if not cfg.has_section("remap"):
		return count
	for key in cfg.get_section_keys("remap"):
		if key == "path" or key.begins_with("path."):
			var value = cfg.get_value("remap", key)
			if typeof(value) == TYPE_STRING and value.begins_with("res://"):
				count += _add_file(packer, value, value, added)
	if cfg.has_section_key("remap", "path") and typeof(cfg.get_value("remap", "path")) == TYPE_ARRAY:
		for value in cfg.get_value("remap", "path"):
			if typeof(value) == TYPE_STRING and value.begins_with("res://"):
				count += _add_file(packer, value, value, added)
	return count
