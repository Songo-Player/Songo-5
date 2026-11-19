@tool
extends RefCounted

# Copies a Songo theme folder into res://theme_dev/themes_raw/<new folder> so
# the copy is fully its own:
#  - res:// paths that point into the source theme are rewritten to the copy,
#    so its scenes load the copied scripts/scenes, not the original's.
#  - Every UID the source theme owns (scene/resource headers, .import files,
#    .uid files) gets a fresh UID, and references to it are updated. Godot
#    resolves a UID before the path, so a kept UID would quietly load the
#    original's file even with a rewritten path.
#  - class_name declarations get the new theme's suffix (two scripts can't
#    share a global class name), and uses of them inside the copy follow.
#  - .import files lose their cached-output lines so the editor reimports the
#    copy under its new path (the reimport keeps the new UID).
#  - theme.json gets the new display name and rootDir (added if missing, as
#    internal themes don't have one).
# References to files outside the source theme (res://assets, res://utilities,
# other themes) are left alone. Ones into another theme are reported, because
# they won't be in this theme's pck.

const ThemeJson := preload("theme_json.gd")

const EXTERNAL_THEMES_DIR := "res://theme_dev/themes_raw"
const INTERNAL_THEMES_DIR := "res://internal_themes"

const TEXT_EXTENSIONS := ["tscn", "tres", "gd", "gdshader", "gdshaderinc", "json", "cfg", "import", "uid", "md", "txt"]
# Binary scenes/resources can hold paths and UIDs we can't rewrite safely.
const BINARY_RESOURCE_EXTENSIONS := ["scn", "res"]

var warnings: PackedStringArray = []
var renamed_classes: Dictionary = {}  # old class_name -> new class_name
var copied_files := 0
var destination := ""

static func is_valid_folder_name(folder_name: String) -> bool:
	var re := RegEx.create_from_string("^[A-Za-z0-9][A-Za-z0-9_-]*$")
	return re.search(folder_name) != null

# The folder name is also the pck mount key at runtime (ThemeManager mounts
# external themes at themes_raw/<folder>), so it has to be unique across every
# theme location, packaged ones included.
static func folder_name_taken(folder_name: String) -> bool:
	for dir in [EXTERNAL_THEMES_DIR, INTERNAL_THEMES_DIR, "res://theme_dev/themes_packaged"]:
		if DirAccess.dir_exists_absolute(dir.path_join(folder_name)):
			return true
	return false

func duplicate_theme(source_root: String, folder_name: String, display_name: String) -> bool:
	source_root = source_root.trim_suffix("/")
	destination = EXTERNAL_THEMES_DIR.path_join(folder_name)
	warnings.clear()
	renamed_classes.clear()
	copied_files = 0

	if not is_valid_folder_name(folder_name):
		warnings.append("Folder name must be letters, numbers, - or _ (and start with a letter or number).")
		return false
	if folder_name_taken(folder_name):
		warnings.append("A theme folder named %s already exists." % folder_name)
		return false
	if not FileAccess.file_exists(source_root.path_join("theme.json")):
		warnings.append("%s has no theme.json." % source_root)
		return false

	var files := _list_files(source_root, "")
	var uid_map := _collect_uids(source_root, files)
	_collect_class_renames(source_root, files, folder_name)
	var foreign_refs := {}

	for rel in files:
		var src := source_root.path_join(rel)
		var dst := destination.path_join(rel)
		var err := DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
		if err != OK:
			warnings.append("Couldn't create %s (%s)" % [dst.get_base_dir(), error_string(err)])
			return false

		var ext := rel.get_extension().to_lower()
		if ext in TEXT_EXTENSIONS:
			var text := FileAccess.get_file_as_string(src)
			_note_foreign_refs(text, source_root, foreign_refs)
			text = _rewrite_text(text, rel, ext, source_root, uid_map, folder_name, display_name)
			var file := FileAccess.open(dst, FileAccess.WRITE)
			if file == null:
				warnings.append("Couldn't write %s (%s)" % [dst, error_string(FileAccess.get_open_error())])
				return false
			file.store_string(text)
			file.close()
		else:
			if ext in BINARY_RESOURCE_EXTENSIONS:
				warnings.append("%s is a binary resource. Paths and UIDs inside it weren't updated; resave it as text (.tscn/.tres) in the source theme first if it references theme files." % rel)
			err = DirAccess.copy_absolute(ProjectSettings.globalize_path(src), ProjectSettings.globalize_path(dst))
			if err != OK:
				warnings.append("Couldn't copy %s (%s)" % [rel, error_string(err)])
				return false
		copied_files += 1

	for ref in foreign_refs:
		warnings.append("References %s, which belongs to another theme and wasn't copied. Copy it into this theme if you want to change it, and note that a packed theme can only rely on internal themes' files." % ref)
	return true

func _list_files(root: String, rel_dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(root.path_join(rel_dir))
	if dir == null:
		return out
	dir.include_hidden = false
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var rel := rel_dir.path_join(name) if rel_dir != "" else name
		if dir.current_is_dir():
			if name != ".godot":
				out.append_array(_list_files(root, rel))
		else:
			out.append(rel)
		name = dir.get_next()
	dir.list_dir_end()
	return out

func _new_uid_text() -> String:
	return ResourceUID.id_to_text(ResourceUID.create_id())

# Only UIDs the source theme itself owns are remapped, so references to shared
# app files (res://assets/...) keep pointing at those files.
func _collect_uids(source_root: String, files: PackedStringArray) -> Dictionary:
	var uid_map := {}
	var header_uid := RegEx.create_from_string("^\\[gd_(?:scene|resource)[^\\]]*\\buid=\"(uid://[a-z0-9]+)\"")
	for rel in files:
		var path := source_root.path_join(rel)
		var old_uid := ""
		match rel.get_extension().to_lower():
			"tscn", "tres":
				var file := FileAccess.open(path, FileAccess.READ)
				if file:
					var m := header_uid.search(file.get_line())
					if m:
						old_uid = m.get_string(1)
			"import":
				var cfg := ConfigFile.new()
				if cfg.load(path) == OK and cfg.has_section_key("remap", "uid"):
					old_uid = str(cfg.get_value("remap", "uid"))
			"uid":
				old_uid = FileAccess.get_file_as_string(path).strip_edges()
		if old_uid.begins_with("uid://") and not uid_map.has(old_uid):
			uid_map[old_uid] = _new_uid_text()
	return uid_map

func _collect_class_renames(source_root: String, files: PackedStringArray, folder_name: String) -> void:
	var suffix := _identifier_suffix(folder_name)
	var taken := {}
	for entry in ProjectSettings.get_global_class_list():
		taken[entry["class"]] = true
	var class_decl := RegEx.create_from_string("(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	for rel in files:
		if rel.get_extension().to_lower() != "gd":
			continue
		var m := class_decl.search(FileAccess.get_file_as_string(source_root.path_join(rel)))
		if m == null:
			continue
		var old_name := m.get_string(1)
		var new_name := old_name + suffix
		var n := 2
		while taken.has(new_name):
			new_name = "%s%s%d" % [old_name, suffix, n]
			n += 1
		taken[new_name] = true
		renamed_classes[old_name] = new_name

func _identifier_suffix(folder_name: String) -> String:
	var out := ""
	for part in folder_name.replace("-", "_").split("_", false):
		out += part.substr(0, 1).to_upper() + part.substr(1)
	return out

func _note_foreign_refs(text: String, source_root: String, found: Dictionary) -> void:
	var re := RegEx.create_from_string("res://(?:internal_themes|theme_dev/themes_raw)/[^\"'\\s)]+")
	for m in re.search_all(text):
		var ref := m.get_string()
		if not ref.begins_with(source_root + "/"):
			found[ref] = true

func _rewrite_text(text: String, rel: String, ext: String, source_root: String, uid_map: Dictionary, folder_name: String, display_name: String) -> String:
	text = text.replace(source_root + "/", destination + "/")
	text = text.replace("\"%s\"" % source_root, "\"%s\"" % destination)

	if ext == "uid":
		var old := text.strip_edges()
		return (uid_map.get(old, old) as String) + "\n"
	for old_uid in uid_map:
		text = text.replace("\"%s\"" % old_uid, "\"%s\"" % uid_map[old_uid])

	if ext == "gd":
		text = _rename_classes(text)
	elif ext == "import":
		text = _strip_import_outputs(text)
	elif rel == "theme.json":
		text = ThemeJson.set_string(text, "name", display_name)
		text = ThemeJson.set_string(text, "rootDir", folder_name)
	return text

# Skips names right after $ % . or a quote, which are node paths, member
# access or strings rather than the class.
func _rename_classes(text: String) -> String:
	var names := renamed_classes.keys()
	names.sort_custom(func(a, b): return a.length() > b.length())
	for old_name in names:
		var re := RegEx.create_from_string("(?<![$%.\"'A-Za-z0-9_])" + old_name + "(?![A-Za-z0-9_])")
		text = re.sub(text, renamed_classes[old_name], true)
	return text

# Drops the cached import output paths (named after the source file's path) so
# the editor reimports the copy; the reimport keeps the [remap] uid.
func _strip_import_outputs(text: String) -> String:
	var out := PackedStringArray()
	for line in text.split("\n"):
		if line.begins_with("path=") or line.begins_with("path.") or line.begins_with("dest_files="):
			continue
		out.append(line)
	return "\n".join(out)
