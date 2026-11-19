@tool
extends RefCounted

# Creates a new, empty external theme in res://theme_dev/themes_raw/<Folder>:
#   theme.json   name, rootDir, version 0.1, empty components and settings
#   theme.tres   an empty Godot Theme, merged over the base theme
#   preview.png  a plain 640x480 placeholder for the theme picker
#   assets/      for the theme's own fonts, images and scripts
#   README.md    how to start filling it in
# Components left out of theme.json use Songo Classic's scenes, and the empty
# settings block gets Songo Classic's defaults for those, so the new theme
# works as soon as it's created.

const Duplicator := preload("theme_duplicator.gd")

const PREVIEW_SIZE := Vector2i(640, 480)
const PREVIEW_COLOR := Color(0.129, 0.129, 0.129)

var error := ""
var destination := ""

# "my cool theme" -> "MyCoolTheme". Each word's first letter is capitalised and
# the rest kept, so "xBop red" -> "XBopRed".
static func folder_name_for(display_name: String) -> String:
	var out := ""
	var word_re := RegEx.create_from_string("[A-Za-z0-9]+")
	for m in word_re.search_all(display_name):
		var word := m.get_string()
		out += word.substr(0, 1).to_upper() + word.substr(1)
	return out

func create_theme(display_name: String) -> bool:
	display_name = display_name.strip_edges()
	var folder := folder_name_for(display_name)
	destination = Duplicator.EXTERNAL_THEMES_DIR.path_join(folder)
	error = ""
	if display_name.is_empty() or folder.is_empty():
		error = "The name needs at least one letter or number."
		return false
	if Duplicator.folder_name_taken(folder):
		error = "A theme folder named %s already exists." % folder
		return false

	var err := DirAccess.make_dir_recursive_absolute(destination.path_join("assets"))
	if err != OK:
		error = "Couldn't create %s (%s)." % [destination, error_string(err)]
		return false

	err = _write_text(destination.path_join("theme.json"), _theme_json(display_name, folder))
	if err == OK:
		err = ResourceSaver.save(Theme.new(), destination.path_join("theme.tres"))
	if err == OK:
		var preview := Image.create(PREVIEW_SIZE.x, PREVIEW_SIZE.y, false, Image.FORMAT_RGB8)
		preview.fill(PREVIEW_COLOR)
		err = preview.save_png(destination.path_join("preview.png"))
	if err == OK:
		err = _write_text(destination.path_join("README.md"), _readme(display_name))
	if err != OK:
		error = "Couldn't write the theme files (%s). A partial theme was left at %s." % [error_string(err), destination]
		return false
	return true

func _theme_json(display_name: String, folder: String) -> String:
	return "\n".join([
		"{",
		"\t\"name\": %s," % JSON.stringify(display_name),
		"\t\"rootDir\": %s," % JSON.stringify(folder),
		"\t\"version\": \"0.1\",",
		"\t\"author\": \"\",",
		"\t\"co_authors\": [],",
		"\t\"description\": \"\",",
		"\t\"components\": {},",
		"\t\"tags\": [],",
		"\t\"settings\": {}",
		"}",
		"",
	])

func _readme(display_name: String) -> String:
	return """# %s

A Songo-5 theme. Edit its name, author, tags and so on from the Songo Themes
dock's theme.json section, and pack it with Pack Theme.

- theme.tres is merged over the app's base theme, so styles, colors, fonts and
  constants set there (e.g. CollectionOptions) apply across the app.
- Components (main_menu, header, footer, background_root, main_song_view,
  song_follow, collection_button, collection_header) not listed under
  "components" in theme.json use Songo Classic's. To customize one, copy its
  folder from another theme into this one and add it to "components", e.g.
  "header": "header/header.tscn". Update the copy's res:// paths to point here.
- preview.png is what the theme picker shows; replace the placeholder with a
  640x480 screenshot.
- Put fonts, images and shared scripts in assets/.
""" % display_name

func _write_text(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK
