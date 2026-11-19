@tool
extends RefCounted

# A theme's components: the scenes it supplies in place of Songo Classic's
# (ThemeManager.THEMABLE_COMPONENTS). theme.json lists each under
# "components", either as a scene path relative to the theme folder
# ("header": "header/header.tscn") or as a switch that picks a scene by a
# setting's value ({"setting": "main_menu_layout", "scenes": {...}}).
#
# New components follow the existing layout: <theme>/<component>/<component>.tscn
# with a MarginContainer root and <component>.gd beside it. The script starts
# with whatever the app calls on that component (see INFO), so a blank one
# loads without errors.

const ThemeJson := preload("theme_json.gd")

const COMPONENTS := ["background_root", "header", "main_menu", "main_song_view", "song_follow", "footer", "collection_header", "collection_button"]

# label: name in the dock. about: what it is. preset: root anchors, as Songo
# Classic's scene for it. methods: script stubs for what the app calls.
# note: shown when it's created.
const INFO := {
	"background_root": {
		"label": "Background",
		"about": "Fills the screen behind everything else.",
		"preset": Control.PRESET_FULL_RECT,
		"methods": "",
	},
	"header": {
		"label": "Header",
		"about": "The bar along the top of the screen (clock, battery and so on).",
		"preset": Control.PRESET_TOP_WIDE,
		"methods": "",
	},
	"main_menu": {
		"label": "Main Menu",
		"about": "The home screen's menu of Songs, Albums, Artists and so on.",
		"preset": Control.PRESET_FULL_RECT,
		"methods": """
# Optional; called once the menu is in the scene tree.
func setup() -> void:
	pass
""",
		"note": "A blank main menu has nothing to select, so Songo's home screen can't be used with this theme until you add menu buttons. See Songo Classic's main_menu_3 for how its menu builds them.",
	},
	"main_song_view": {
		"label": "Now Playing",
		"about": "The now playing screen.",
		"preset": Control.PRESET_FULL_RECT,
		"methods": """
# Called with the track whenever a new one starts (and when its info changes).
func setup_display_for(music_record: TagLibMusicRecord) -> void:
	pass

# Optional. Named for what was just done: display_play_button means playback
# started, so show a pause button; display_pause_button the reverse.
func display_play_button() -> void:
	pass

func display_pause_button() -> void:
	pass
""",
	},
	"song_follow": {
		"label": "Song Follow",
		"about": "The small now playing display shown while browsing.",
		"preset": Control.PRESET_TOP_WIDE,
		"methods": """
# Called with the track whenever a new one starts.
func setup_display_for(music_record: TagLibMusicRecord) -> void:
	pass
""",
	},
	"footer": {
		"label": "Footer",
		"about": "The bar along the bottom of the screen.",
		"preset": Control.PRESET_BOTTOM_WIDE,
		"methods": "",
	},
	"collection_header": {
		"label": "List Header",
		"about": "Shown above song, album, artist and playlist lists, with the sort order.",
		"preset": Control.PRESET_TOP_WIDE,
		"methods": """
# Called when the list is shown or re-sorted, with the sort it's using.
func setup(sort_key) -> void:
	pass
""",
	},
	"collection_button": {
		"label": "List Item",
		"about": "One row in the song, album, artist and playlist lists.",
		"preset": Control.PRESET_TOP_WIDE,
		"methods": """
# One of these is called for each row, depending on what the list shows.
# Songo calls them without checking they exist, so keep all four.
#
# Optional layout: give the root a child per record type named
# SongButtonContainer, AlbumButtonContainer, ArtistButtonContainer and
# PlaylistButtonContainer. Songo keeps only the one a row needs, so a script
# must only touch the container for the record type it's given.
func setup_music_record(record) -> void:
	pass

func setup_album_record(record) -> void:
	pass

func setup_artist_record(record) -> void:
	pass

func setup_playlist_record(record) -> void:
	pass
""",
	},
}

var theme_dir := ""
var components := {}  # parsed "components" from theme.json
var error := ""

func _init(p_theme_dir: String) -> void:
	theme_dir = p_theme_dir

func load_json(text: String) -> void:
	var data := ThemeJson.parse(text)
	components = data["components"] if data.get("components") is Dictionary else {}

# For one component: { "kind": "none" | "scene" | "switch" | "missing",
#   "path": res:// path (scene/missing), "relative": as in theme.json,
#   "scenes": { value: res:// path } (switch), "setting": key (switch) }
func status(component: String) -> Dictionary:
	var entry = components.get(component)
	if entry == null:
		return {"kind": "none"}
	if entry is Dictionary:
		var scenes := {}
		if entry.get("scenes") is Dictionary:
			for value in entry["scenes"]:
				scenes[value] = theme_dir.path_join(str(entry["scenes"][value]))
		return {"kind": "switch", "setting": str(entry.get("setting", "")), "scenes": scenes}
	var path := theme_dir.path_join(str(entry))
	return {"kind": "scene" if FileAccess.file_exists(path) else "missing", "path": path, "relative": str(entry)}

static func default_relative(component: String) -> String:
	return "%s/%s.tscn" % [component, component]

static func root_name(component: String) -> String:
	return component.to_pascal_case()

# Writes <component>/<component>.gd and .tscn. Returns the theme.json text
# with the component added; "" (and error set) if something failed.
func create(component: String, json_text: String) -> String:
	error = ""
	var relative := default_relative(component)
	var scene_path := theme_dir.path_join(relative)
	var script_path := scene_path.get_basename() + ".gd"
	if FileAccess.file_exists(scene_path) or FileAccess.file_exists(script_path):
		error = "%s already has files at %s; open or delete them instead." % [component, scene_path.get_base_dir()]
		return ""
	var err := DirAccess.make_dir_recursive_absolute(scene_path.get_base_dir())
	if err != OK:
		error = "Couldn't create %s (%s)." % [scene_path.get_base_dir(), error_string(err)]
		return ""

	var file := FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		error = "Couldn't write %s (%s)." % [script_path, error_string(FileAccess.get_open_error())]
		return ""
	file.store_string(_script_text(component))
	file.close()

	var root := MarginContainer.new()
	root.name = root_name(component)
	root.set_anchors_and_offsets_preset(INFO[component]["preset"])
	var script: Script = ResourceLoader.load(script_path, "Script", ResourceLoader.CACHE_MODE_REPLACE)
	if script:
		root.set_script(script)
	var packed := PackedScene.new()
	err = packed.pack(root)
	root.free()
	if err == OK:
		err = ResourceSaver.save(packed, scene_path)
	if err != OK:
		error = "Couldn't save %s (%s)." % [scene_path, error_string(err)]
		return ""

	var after := ""
	var data := ThemeJson.parse(json_text)
	for candidate in ["description", "ai_usage", "co_authors", "author", "version", "name"]:
		if data.has(candidate):
			after = candidate
			break
	return ThemeJson.set_object_entry(json_text, "components", component, JSON.stringify(relative), after)

func _script_text(component: String) -> String:
	var info: Dictionary = INFO[component]
	var text := "extends MarginContainer\n\n# %s component: %s\n" % [info["label"], info["about"]]
	text += "# Theme settings: ThemeManager.settings.get(\"key\")\n"
	var methods: String = info["methods"]
	if methods == "":
		text += "\nfunc _ready() -> void:\n\tpass\n"
	else:
		text += methods
	return text

# Files Delete would remove: the scene, and its root script when that lives in
# the component's own folder (shared scripts elsewhere are left alone).
func files_to_delete(component: String) -> PackedStringArray:
	var st := status(component)
	var out := PackedStringArray()
	if st["kind"] != "scene":
		return out
	var scene_path: String = st["path"]
	out.append(scene_path)
	var script_path := _root_script_path(scene_path)
	if script_path != "" and script_path.get_base_dir() == scene_path.get_base_dir() and FileAccess.file_exists(script_path):
		out.append(script_path)
	return out

func _root_script_path(scene_path: String) -> String:
	var state := (ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene)
	if state == null:
		return ""
	var scene_state := state.get_state()
	for i in scene_state.get_node_property_count(0):
		if scene_state.get_node_property_name(0, i) == "script":
			var script = scene_state.get_node_property_value(0, i)
			return script.resource_path if script is Script else ""
	return ""

# Moves the component's files to the trash (or deletes them if there's no
# trash), removes its folder if that leaves it empty, and returns theme.json
# text without the component; "" (and error set) if a file couldn't go.
func delete(component: String, json_text: String) -> String:
	error = ""
	var files := files_to_delete(component)
	for path in files:
		for extra in [path, path + ".uid"]:
			if not FileAccess.file_exists(extra):
				continue
			var abs_path := ProjectSettings.globalize_path(extra)
			if OS.move_to_trash(abs_path) != OK and DirAccess.remove_absolute(abs_path) != OK:
				error = "Couldn't delete %s." % extra
				return ""
	if not files.is_empty():
		var folder := files[0].get_base_dir()
		if folder != theme_dir and DirAccess.dir_exists_absolute(folder):
			var dir := DirAccess.open(folder)
			if dir and dir.get_files().is_empty() and dir.get_directories().is_empty():
				OS.move_to_trash(ProjectSettings.globalize_path(folder))
	return ThemeJson.remove_object_entry(json_text, "components", component)
