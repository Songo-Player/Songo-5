@tool
extends VBoxContainer

# "Songo Themes" dock: lists internal and in-development themes, packs an
# external theme (theme_dev/theme_packer.gd's pack_theme, which also mirrors
# it to user://external_themes for the app to pick up), and duplicates any
# theme into a new, independent external theme.

const Duplicator := preload("theme_duplicator.gd")
const ThemeJson := preload("theme_json.gd")
const Scaffold := preload("theme_scaffold.gd")
const SettingsWindow := preload("theme_settings_window.gd")
const Components := preload("theme_components.gd")
const SettingsModel := preload("settings_model.gd")
const ThemePreview := preload("theme_preview.gd")
# Gives up on a capture run that hasn't finished in this long.
const CAPTURE_TIMEOUT_MSEC := 30000

# Top-level theme.json values edited by the theme.json section, in display
# order: [key, label, kind]. "string" is a text box; "list" is an array of
# strings edited row by row and saved inline (["a", "b"]); "ai_usage" is a
# whole number from AI_USAGE_MIN to AI_USAGE_MAX, or absent when not set. The
# description has its own multi-line box below these.
const META_FIELDS := [
	["name", "Name", "string"],
	["version", "Version", "string"],
	["author", "Author", "string"],
	["co_authors", "Co-Authors", "list"],
	["ai_usage", "AI Usage", "ai_usage"],
	["tags", "Tags", "list"],
]
const AI_USAGE_MIN := 0
const AI_USAGE_MAX := 5
const AI_USAGE_NOT_SET := -1
# Where a key goes when a theme.json doesn't have it yet: after the first of
# these keys the file has (otherwise at the top).
const META_INSERT_AFTER := {
	"version": ["name"],
	"author": ["version", "name"],
	"co_authors": ["author", "version", "name"],
	"ai_usage": ["co_authors", "author", "version", "name"],
	"description": ["ai_usage", "co_authors", "author", "version", "name"],
	"tags": ["description", "ai_usage", "co_authors", "author", "name"],
}
const StringListEditor := preload("string_list_editor.gd")
# Seconds after the last change before the theme.json section saves.
const META_AUTOSAVE_DELAY := 0.6
const PACKER_SCRIPT := "res://theme_dev/theme_packer.gd"
const INTERNAL_DIR := "res://internal_themes"
const EXTERNAL_DIR := "res://theme_dev/themes_raw"
const PACKAGED_DIR := "res://theme_dev/themes_packaged"
const MIRROR_DIR := "user://external_themes"

var _themes: Array[Dictionary] = []

var _picker: OptionButton
var _refresh_button: Button
var _info: RichTextLabel
var _pack_button: Button
var _show_button: Button
var _open_output_button: Button
var _duplicate_button: Button
var _log: RichTextLabel

var _meta_toggle: Button
var _meta_box: VBoxContainer
var _meta_fields := {}  # key -> LineEdit (string fields)
var _meta_lists := {}   # key -> StringListEditor (list fields)
var _meta_ai_usage: OptionButton  # item id = value, AI_USAGE_NOT_SET for none
var _meta_ai_usage_note := ""      # set when the file holds an out-of-range value
var _meta_description: TextEdit
var _meta_root_dir: Label
var _meta_status: Label
var _meta_timer: Timer        # autosave, restarted on every change
var _meta_original := {}      # values when this theme was selected (for the name/version note)
var _meta_saved_once := false
var _meta_path := ""       # theme.json being edited
var _meta_loaded := {}     # values as last loaded/saved, for change tracking
var _meta_loading := false

var _preview_rect: TextureRect
var _preview_choose: Button
var _preview_capture: Button
var _preview_status: Label
var _preview_dialog: EditorFileDialog
var _capture_timer: Timer
var _capture_pid := -1
var _capture_dir := ""     # theme being captured
var _capture_started := 0

var _set_toggle: Button
var _set_box: VBoxContainer
var _set_rows: VBoxContainer
var _set_add: MenuButton
var _settings_window: Window

var _comp_toggle: Button
var _comp_box: VBoxContainer
var _comp_rows: VBoxContainer
var _comp_delete_dialog: ConfirmationDialog
var _comp_pending_delete := ""

var _new_theme_button: Button
var _new_dialog: ConfirmationDialog
var _new_name: LineEdit
var _new_folder_label: Label
var _new_error: Label

var _dup_dialog: ConfirmationDialog
var _dup_source_label: Label
var _dup_folder: LineEdit
var _dup_name: LineEdit
var _dup_error: Label

func _exit_tree() -> void:
	_flush_meta()
	if _capture_pid > 0 and OS.is_process_running(_capture_pid):
		OS.kill(_capture_pid)
	if _settings_window:
		_settings_window.queue_free()
		_settings_window = null

# Opens the Theme Settings window, on a setting (key) or adding a new one of
# a type (add_kind, an index into SettingsModel.KINDS).
func _open_settings_window(key := "", add_kind := -1) -> void:
	var theme := _selected()
	if theme.is_empty() or not theme["valid_json"]:
		return
	if _settings_window == null:
		_settings_window = SettingsWindow.new()
		_settings_window.saved.connect(func():
			_log_line("[color=#7ad37a]Saved settings to %s.[/color]" % _settings_window.json_path)
			refresh())
		EditorInterface.get_base_control().add_child(_settings_window)
	var json_path: String = theme["path"].path_join("theme.json")
	if _settings_window.visible and _settings_window.json_path != json_path and _settings_window.is_dirty():
		_log_line("[color=#e0b050]The Theme Settings window has unsaved changes for %s. Save or close it first.[/color]" % _settings_window.theme_name)
		_settings_window.grab_focus()
		return
	_settings_window.open_for(theme["path"], theme["name"], _write_json_in_editor, key, add_kind)

func _ready() -> void:
	_build_ui()
	refresh()

func _build_ui() -> void:
	add_theme_constant_override("separation", 6)

	var row := HBoxContainer.new()
	_picker = OptionButton.new()
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.clip_text = true
	_picker.item_selected.connect(func(_i): _update_info())
	row.add_child(_picker)
	_refresh_button = Button.new()
	_refresh_button.tooltip_text = "Rescan theme folders and reload theme.json."
	_refresh_button.icon = _editor_icon("Reload")
	_refresh_button.pressed.connect(func():
		_flush_meta()
		refresh()
		_load_meta(_selected(), true))
	row.add_child(_refresh_button)
	add_child(row)

	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.selection_enabled = true
	add_child(_info)

	_pack_button = _add_button("Pack Theme", "Save all scenes, pack this theme into theme_dev/themes_packaged and mirror it to user://external_themes.", "Save", _on_pack_pressed)
	_new_theme_button = _add_button("New Theme…", "Create a new, empty external theme in theme_dev/themes_raw.", "Add", _on_new_theme_pressed)
	_duplicate_button = _add_button("Duplicate Theme…", "Copy this theme into a new external theme that uses its own scripts and scenes.", "Duplicate", _on_duplicate_pressed)

	var tools := HBoxContainer.new()
	_show_button = Button.new()
	_show_button.text = "Show in FileSystem"
	_show_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_show_button.pressed.connect(_on_show_pressed)
	tools.add_child(_show_button)
	_open_output_button = Button.new()
	_open_output_button.text = "Open Packed Folder"
	_open_output_button.tooltip_text = "Open user://external_themes, where packed themes are mirrored for the app."
	_open_output_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_open_output_button.pressed.connect(_on_open_output_pressed)
	tools.add_child(_open_output_button)
	add_child(tools)

	add_child(HSeparator.new())
	_build_meta_section()
	add_child(HSeparator.new())
	_build_settings_section()
	add_child(HSeparator.new())
	_build_components_section()
	add_child(HSeparator.new())
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size.y = 120
	add_child(_log)

	_build_duplicate_dialog()
	_build_new_theme_dialog()
	_wrap_in_scroll()

# Moves everything built above into a ScrollContainer, so expanding sections
# scrolls the dock instead of making the editor window taller than the screen.
# Dialogs are windows, not dock content, so they stay where they are.
func _wrap_in_scroll() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Fills the dock when there's room, so the log still takes the leftover space.
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for child in get_children():
		if child is Window:
			continue
		remove_child(child)
		content.add_child(child)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	add_child(scroll)

func _build_meta_section() -> void:
	_meta_toggle = Button.new()
	_meta_toggle.text = "Theme Info"
	_meta_toggle.flat = true
	_meta_toggle.toggle_mode = true
	_meta_toggle.button_pressed = false  # starts collapsed
	_meta_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_meta_toggle.toggled.connect(_on_meta_toggled)
	add_child(_meta_toggle)

	_meta_box = VBoxContainer.new()
	add_child(_meta_box)
	_build_preview_row()

	var grid := GridContainer.new()
	grid.columns = 2
	_meta_box.add_child(grid)
	for field in META_FIELDS:
		if field[2] == "ai_usage":
			_meta_ai_usage = OptionButton.new()
			_meta_ai_usage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_meta_ai_usage.tooltip_text = "How much AI was used to make this theme, from %d to %d." % [AI_USAGE_MIN, AI_USAGE_MAX]
			_meta_ai_usage.add_item("Not set", AI_USAGE_NOT_SET)
			for value in range(AI_USAGE_MIN, AI_USAGE_MAX + 1):
				_meta_ai_usage.add_item(str(value), value)
			_meta_ai_usage.item_selected.connect(func(_i): _on_meta_changed())
			_add_meta_row(grid, field[1], _meta_ai_usage)
		elif field[2] == "list":
			var list := StringListEditor.new("Add " + field[1].to_lower().trim_suffix("s"))
			list.changed.connect(_on_meta_changed)
			_meta_lists[field[0]] = list
			_add_meta_row(grid, field[1], list)
		else:
			var edit := LineEdit.new()
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.text_changed.connect(func(_t): _on_meta_changed())
			_meta_fields[field[0]] = edit
			_add_meta_row(grid, field[1], edit)
	_meta_fields["version"].tooltip_text = "Players' choices for this theme's settings are saved per name + version, so changing either starts them fresh."
	_meta_fields["name"].tooltip_text = _meta_fields["version"].tooltip_text
	_meta_lists["co_authors"].placeholder = "Name"
	_meta_lists["tags"].placeholder = "e.g. dark"

	_meta_root_dir = Label.new()
	_meta_root_dir.tooltip_text = "Set from the theme's folder name; it has to match for packed themes to load."
	_add_meta_row(grid, "Root dir", _meta_root_dir)

	_meta_box.add_child(_make_label("Description"))
	_meta_description = TextEdit.new()
	_meta_description.custom_minimum_size.y = 72
	_meta_description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_meta_description.text_changed.connect(_on_meta_changed)
	_meta_box.add_child(_meta_description)

	_meta_status = Label.new()
	_meta_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meta_box.add_child(_meta_status)

	# Changes save themselves a moment after the last edit.
	_meta_timer = Timer.new()
	_meta_timer.one_shot = true
	_meta_timer.wait_time = META_AUTOSAVE_DELAY
	_meta_timer.timeout.connect(_save_meta)
	add_child(_meta_timer)
	_on_meta_toggled(false)

func _add_meta_row(grid: GridContainer, label_text: String, control: Control) -> void:
	var label := _make_label(label_text)
	label.custom_minimum_size.x = 84
	if control is StringListEditor:
		# Line up with the first row rather than the middle of the list.
		label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		label.custom_minimum_size.y = 31
	grid.add_child(label)
	grid.add_child(control)

func _add_button(text: String, tooltip: String, icon_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.icon = _editor_icon(icon_name)
	button.pressed.connect(callback)
	add_child(button)
	return button

func _build_duplicate_dialog() -> void:
	_dup_dialog = ConfirmationDialog.new()
	_dup_dialog.title = "Duplicate Songo Theme"
	_dup_dialog.ok_button_text = "Duplicate"
	_dup_dialog.confirmed.connect(_on_duplicate_confirmed)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	_dup_source_label = Label.new()
	box.add_child(_dup_source_label)

	box.add_child(_make_label("Folder name (in theme_dev/themes_raw):"))
	_dup_folder = LineEdit.new()
	_dup_folder.placeholder_text = "MyTheme"
	_dup_folder.text_changed.connect(func(_t): _validate_duplicate())
	box.add_child(_dup_folder)

	box.add_child(_make_label("Display name (theme.json \"name\"):"))
	_dup_name = LineEdit.new()
	_dup_name.placeholder_text = "My Theme"
	_dup_name.text_changed.connect(func(_t): _validate_duplicate())
	box.add_child(_dup_name)

	_dup_error = Label.new()
	_dup_error.add_theme_color_override("font_color", _editor_color("error_color", Color(1, 0.47, 0.42)))
	_dup_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_dup_error)

	_dup_dialog.add_child(box)
	_dup_dialog.register_text_enter(_dup_folder)
	_dup_dialog.register_text_enter(_dup_name)
	add_child(_dup_dialog)

func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

func _editor_icon(icon_name: String) -> Texture2D:
	var editor_theme := EditorInterface.get_editor_theme()
	if editor_theme and editor_theme.has_icon(icon_name, "EditorIcons"):
		return editor_theme.get_icon(icon_name, "EditorIcons")
	return null

func _editor_color(color_name: String, fallback: Color) -> Color:
	var editor_theme := EditorInterface.get_editor_theme()
	if editor_theme and editor_theme.has_color(color_name, "Editor"):
		return editor_theme.get_color(color_name, "Editor")
	return fallback

# ---- Theme list ----

func refresh() -> void:
	var selected_path := ""
	var current := _selected()
	if not current.is_empty():
		selected_path = current["path"]

	_themes.clear()
	_scan_themes(INTERNAL_DIR, false)
	_scan_themes(EXTERNAL_DIR, true)

	_picker.clear()
	var section := ""
	for i in _themes.size():
		var theme: Dictionary = _themes[i]
		var theme_section := "External (themes_raw)" if theme["external"] else "Internal"
		if theme_section != section:
			_picker.add_separator(theme_section)
			section = theme_section
		_picker.add_item("%s  (%s)" % [theme["name"], theme["dir_name"]])
		_picker.set_item_metadata(_picker.item_count - 1, i)
		if theme["path"] == selected_path:
			_picker.select(_picker.item_count - 1)
	if _picker.selected < 0:
		for idx in _picker.item_count:
			if not _picker.is_item_separator(idx):
				_picker.select(idx)
				break
	_update_info()

func _scan_themes(root: String, external: bool) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	var names := Array(dir.get_directories())
	names.sort()
	for dir_name in names:
		var path: String = root.path_join(dir_name)
		var json_path := path.path_join("theme.json")
		if not FileAccess.file_exists(json_path):
			continue
		var data := ThemeJson.parse(FileAccess.get_file_as_string(json_path))
		_themes.append({
			"path": path,
			"dir_name": dir_name,
			"external": external,
			"name": str(data.get("name", dir_name)),
			"version": str(data.get("version", "?")),
			"author": str(data.get("author", "?")),
			"valid_json": not data.is_empty(),
			"settings_count": data["settings"].size() if data.get("settings") is Dictionary else 0,
		})

func _selected() -> Dictionary:
	if _picker == null or _picker.selected < 0 or _picker.is_item_separator(_picker.selected):
		return {}
	var index = _picker.get_item_metadata(_picker.selected)
	if typeof(index) != TYPE_INT or index >= _themes.size():
		return {}
	return _themes[index]

func _update_info() -> void:
	var theme := _selected()
	var has_theme := not theme.is_empty()
	_pack_button.disabled = not has_theme or not theme["external"]
	_duplicate_button.disabled = not has_theme
	_show_button.disabled = not has_theme
	_load_meta(theme)
	_refresh_settings_list(theme)
	_refresh_components(theme)
	if not has_theme:
		_info.text = "[i]No themes found in %s or %s.[/i]" % [INTERNAL_DIR, EXTERNAL_DIR]
		return

	_pack_button.tooltip_text = "Save all scenes, pack this theme into theme_dev/themes_packaged and mirror it to user://external_themes." if theme["external"] \
		else "Internal themes ship inside the app, so they don't need packing. Duplicate one to make an external theme."
	var lines := PackedStringArray()
	lines.append("[b]%s[/b]  v%s  by %s" % [theme["name"], theme["version"], theme["author"]])
	lines.append("[color=gray]%s[/color]" % theme["path"])
	if not theme["valid_json"]:
		lines.append("[color=#ff786b]theme.json didn't parse. The app will fall back to Songo Classic.[/color]")
	# Songo uses <theme>/theme.tres as the theme's Godot Theme when it's there.
	if FileAccess.file_exists(theme["path"].path_join("theme.tres")):
		lines.append("[color=gray]Godot theme: theme.tres[/color]")
	else:
		lines.append("[color=gray]No theme.tres, so only the base theme applies.[/color]")
	if theme["external"]:
		lines.append(_pack_status(theme))
	else:
		lines.append("[color=gray]Internal theme, ships with the app.[/color]")
	_info.text = "\n".join(lines)

func _pack_status(theme: Dictionary) -> String:
	var pck: String = PACKAGED_DIR.path_join(theme["dir_name"]).path_join("theme.pck")
	if not FileAccess.file_exists(pck):
		return "[color=#e0b050]Not packed yet.[/color]"
	var packed_at := FileAccess.get_modified_time(pck)
	var newest := _newest_mtime(theme["path"])
	var when := Time.get_datetime_string_from_unix_time(packed_at + _utc_offset(), true)
	if newest > packed_at:
		return "[color=#e0b050]Packed %s, but files changed since. Pack again.[/color]" % when
	return "[color=#7ad37a]Packed %s, up to date.[/color]" % when

func _utc_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60

func _newest_mtime(path: String) -> int:
	var newest := 0
	var dir := DirAccess.open(path)
	if dir == null:
		return newest
	for file_name in dir.get_files():
		newest = maxi(newest, FileAccess.get_modified_time(path.path_join(file_name)))
	for sub in dir.get_directories():
		if sub != ".godot":
			newest = maxi(newest, _newest_mtime(path.path_join(sub)))
	return newest

# ---- theme.json section ----

# ---- Preview image (in Theme Info) ----

# preview.png is what the theme picker shows. It can be any image (fitted to
# 640x480) or a screenshot of Songo's main menu with the theme applied.
func _build_preview_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_meta_box.add_child(row)
	_preview_rect = TextureRect.new()
	_preview_rect.custom_minimum_size = Vector2(128, 96)
	_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_rect.tooltip_text = "preview.png: shown in Songo's theme picker."
	row.add_child(_preview_rect)

	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(side)
	side.add_child(_make_label("Preview image"))
	_preview_choose = Button.new()
	_preview_choose.text = "Choose image…"
	_preview_choose.icon = _editor_icon("Load")
	_preview_choose.tooltip_text = "Use an image as preview.png. It's scaled to fill 640x480 and cropped evenly if its shape differs."
	_preview_choose.pressed.connect(func(): _preview_dialog.popup_file_dialog())
	side.add_child(_preview_choose)
	_preview_capture = Button.new()
	_preview_capture.text = "Capture from Songo"
	_preview_capture.icon = _editor_icon("Camera")
	_preview_capture.tooltip_text = "Run Songo with this theme, screenshot its main menu and use that as preview.png. A Songo window opens for a few seconds; your saved theme isn't changed."
	_preview_capture.pressed.connect(_on_capture_preview)
	side.add_child(_preview_capture)
	_preview_status = _muted_label("")
	_preview_status.visible = false
	side.add_child(_preview_status)

	_preview_dialog = EditorFileDialog.new()
	_preview_dialog.title = "Choose a preview image"
	_preview_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_preview_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_preview_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp, *.bmp, *.tga ; Images"])
	_preview_dialog.file_selected.connect(_on_preview_file_selected)
	add_child(_preview_dialog)

	_capture_timer = Timer.new()
	_capture_timer.wait_time = 0.25
	_capture_timer.timeout.connect(_poll_capture)
	add_child(_capture_timer)

func _show_preview() -> void:
	var theme := _selected()
	_preview_rect.texture = null if theme.is_empty() else ThemePreview.load_texture(theme["path"])
	var busy := _capture_pid > 0
	_preview_choose.disabled = theme.is_empty() or busy
	_preview_capture.disabled = theme.is_empty() or busy
	if not busy:
		_set_preview_status("" if theme.is_empty() or _preview_rect.texture else "No preview.png yet.")

func _set_preview_status(text: String) -> void:
	_preview_status.text = text
	_preview_status.visible = text != ""

func _on_preview_file_selected(path: String) -> void:
	var theme := _selected()
	if theme.is_empty():
		return
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		_log_line("[color=#ff786b]Couldn't read %s as an image.[/color]" % path)
		return
	var err := ThemePreview.save(image, theme["path"])
	if err != OK:
		_log_line("[color=#ff786b]Couldn't save preview.png (%s).[/color]" % error_string(err))
		return
	_log_line("[color=#7ad37a]Set %s's preview from %s.[/color]" % [theme["dir_name"], path.get_file()])
	_show_preview()

func _on_capture_preview() -> void:
	var theme := _selected()
	if theme.is_empty() or _capture_pid > 0:
		return
	# The run loads scenes from disk, so unsaved edits would be missed.
	EditorInterface.save_all_scenes()
	var temp := ProjectSettings.globalize_path(ThemePreview.CAPTURE_TEMP)
	if FileAccess.file_exists(temp):
		DirAccess.remove_absolute(temp)
	_capture_pid = OS.create_process(OS.get_executable_path(), ThemePreview.capture_args(theme["path"]))
	if _capture_pid <= 0:
		_capture_pid = -1
		_log_line("[color=#ff786b]Couldn't start Songo to capture a preview.[/color]")
		return
	_capture_dir = theme["path"]
	_capture_started = Time.get_ticks_msec()
	_capture_timer.start()
	_set_preview_status("Capturing… a Songo window opens for a few seconds.")
	_show_preview()

func _poll_capture() -> void:
	var running := OS.is_process_running(_capture_pid)
	var timed_out := Time.get_ticks_msec() - _capture_started > CAPTURE_TIMEOUT_MSEC
	if running and not timed_out:
		return
	if running:
		OS.kill(_capture_pid)
	_capture_timer.stop()
	_capture_pid = -1
	var temp := ProjectSettings.globalize_path(ThemePreview.CAPTURE_TEMP)
	var image := Image.load_from_file(temp) if FileAccess.file_exists(temp) else null
	if image == null or image.is_empty():
		_set_preview_status("")
		if timed_out:
			_log_line("[color=#ff786b]The preview capture didn't finish within %d seconds, so it was stopped.[/color]" % (CAPTURE_TIMEOUT_MSEC / 1000))
		else:
			_log_line("[color=#ff786b]Songo closed without a screenshot. Run the project with this theme to see what's going wrong.[/color]")
		_show_preview()
		return
	DirAccess.remove_absolute(temp)
	var err := ThemePreview.save(image, _capture_dir)
	if err != OK:
		_log_line("[color=#ff786b]Couldn't save preview.png (%s).[/color]" % error_string(err))
	else:
		_log_line("[color=#7ad37a]Captured a new preview for %s.[/color]" % _capture_dir.get_file())
	_set_preview_status("")
	_show_preview()

# ---- Theme Settings section ----

func _build_settings_section() -> void:
	_set_toggle = Button.new()
	_set_toggle.text = "Theme Settings"
	_set_toggle.flat = true
	_set_toggle.toggle_mode = true
	_set_toggle.button_pressed = false  # starts collapsed
	_set_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_set_toggle.icon = _editor_icon("GuiTreeArrowRight")
	_set_toggle.toggled.connect(func(on):
		_set_box.visible = on
		_set_toggle.icon = _editor_icon("GuiTreeArrowDown" if on else "GuiTreeArrowRight"))
	add_child(_set_toggle)

	_set_box = VBoxContainer.new()
	_set_box.visible = false
	add_child(_set_box)
	_set_rows = VBoxContainer.new()
	_set_rows.add_theme_constant_override("separation", 0)
	_set_box.add_child(_set_rows)

	_set_add = MenuButton.new()
	_set_add.text = "Add setting"
	_set_add.flat = false
	_set_add.icon = _editor_icon("Add")
	_set_add.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_set_add.tooltip_text = "Add a setting players can change, and open it in the settings editor."
	var popup := _set_add.get_popup()
	for i in SettingsModel.KINDS.size():
		var kind: String = SettingsModel.KINDS[i]
		popup.add_icon_item(_editor_icon(SettingsWindow.KIND_ICONS[kind]), SettingsModel.KIND_NAMES[kind], i)
		popup.set_item_tooltip(i, SettingsModel.KIND_HINTS[kind])
	popup.id_pressed.connect(func(id): _open_settings_window("", id))
	_set_box.add_child(_set_add)

# One row per setting, in the order players see them; clicking one opens it
# in the settings editor.
func _refresh_settings_list(theme: Dictionary) -> void:
	for child in _set_rows.get_children():
		_set_rows.remove_child(child)
		child.queue_free()
	_set_add.disabled = theme.is_empty() or not theme["valid_json"]
	if _set_add.disabled:
		return
	var model := SettingsModel.new()
	model.load_from_text(FileAccess.get_file_as_string(theme["path"].path_join("theme.json")))
	if model.error != "":
		_set_rows.add_child(_muted_label(model.error))
		return
	if model.entries.is_empty():
		_set_rows.add_child(_muted_label("No settings yet. Players get a list of these under Settings → UI & Customization."))
		return
	for entry in model.entries:
		var data: Dictionary = entry["data"]
		var name := str(data.get("display_name", "")).strip_edges()
		var conditional: bool = data.get("visible_when") is Dictionary and not data["visible_when"].is_empty()
		var row := Button.new()
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.text = "%s%s" % ["↳ " if conditional else "", name if name != "" else entry["key"]]
		row.icon = _editor_icon(SettingsWindow.KIND_ICONS[entry["kind"]])
		row.tooltip_text = "%s\nKey: %s\n\nClick to edit." % [SettingsModel.KIND_NAMES[entry["kind"]], entry["key"]]
		var key: String = entry["key"]
		row.pressed.connect(func(): _open_settings_window(key))
		_set_rows.add_child(row)

func _muted_label(text: String) -> Label:
	var label := _make_label(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", _editor_color("font_readonly_color", Color(0.65, 0.65, 0.65)))
	return label

# ---- Components section ----

func _build_components_section() -> void:
	_comp_toggle = Button.new()
	_comp_toggle.text = "Theme Components"
	_comp_toggle.flat = true
	_comp_toggle.toggle_mode = true
	_comp_toggle.button_pressed = true
	_comp_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_comp_toggle.toggled.connect(func(on):
		_comp_box.visible = on
		_comp_toggle.icon = _editor_icon("GuiTreeArrowDown" if on else "GuiTreeArrowRight"))
	_comp_toggle.icon = _editor_icon("GuiTreeArrowDown")
	add_child(_comp_toggle)

	_comp_box = VBoxContainer.new()
	add_child(_comp_box)
	var hint := _make_label("Components you add replace Songo Classic's in this theme; the rest use Songo Classic's.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", _editor_color("font_readonly_color", Color(0.65, 0.65, 0.65)))
	_comp_box.add_child(hint)
	_comp_rows = VBoxContainer.new()
	_comp_box.add_child(_comp_rows)

	_comp_delete_dialog = ConfirmationDialog.new()
	_comp_delete_dialog.title = "Delete component"
	_comp_delete_dialog.ok_button_text = "Delete"
	_comp_delete_dialog.confirmed.connect(_on_component_delete_confirmed)
	add_child(_comp_delete_dialog)

func _components_for(theme: Dictionary):
	var comps := Components.new(theme["path"])
	comps.load_json(FileAccess.get_file_as_string(theme["path"].path_join("theme.json")))
	return comps

func _refresh_components(theme: Dictionary) -> void:
	for child in _comp_rows.get_children():
		_comp_rows.remove_child(child)
		child.queue_free()
	if theme.is_empty() or not theme["valid_json"]:
		return
	var comps = _components_for(theme)
	var muted := _editor_color("font_readonly_color", Color(0.65, 0.65, 0.65))
	for component in Components.COMPONENTS:
		var info: Dictionary = Components.INFO[component]
		var st: Dictionary = comps.status(component)
		var row := HBoxContainer.new()
		var name_label := _make_label(info["label"])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		name_label.tooltip_text = "%s\n(%s)" % [info["about"], component]
		row.add_child(name_label)
		var state := _make_label("")
		state.add_theme_color_override("font_color", muted)
		row.add_child(state)
		match st["kind"]:
			"none":
				state.text = "Songo Classic's"
				row.add_child(_comp_button("Add", "Create %s/%s.tscn with a blank MarginContainer and script, and use it for this theme." % [component, component], func(): _on_component_add(theme, component)))
			"scene":
				# No status text once the theme has its own; the buttons say enough,
				# and the path is in the name's tooltip.
				state.hide()
				name_label.tooltip_text += "\n%s" % st["path"]
				var open := _comp_button("PackedScene", "Open %s in the editor." % st["relative"], func(): EditorInterface.open_scene_from_path(st["path"]))
				open.text = "Open"
				row.add_child(open)
				row.add_child(_comp_button("Remove", "Delete this component's scene and script.", func(): _on_component_delete(theme, component)))
			"missing":
				state.text = "file missing"
				state.add_theme_color_override("font_color", _editor_color("warning_color", Color(0.88, 0.69, 0.31)))
				state.tooltip_text = "theme.json lists %s, but there's no file there." % st["path"]
				state.mouse_filter = Control.MOUSE_FILTER_PASS
				row.add_child(_comp_button("Add", "Create %s/%s.tscn and point theme.json at it." % [component, component], func(): _on_component_add(theme, component)))
				row.add_child(_comp_button("Remove", "Remove it from theme.json so Songo Classic's is used.", func(): _on_component_delete(theme, component)))
			"switch":
				var scenes: Dictionary = st["scenes"]
				state.text = "%d scenes" % scenes.size()
				var setting := str(st["setting"])
				state.tooltip_text = "Picks a scene by the %s setting." % setting
				state.mouse_filter = Control.MOUSE_FILTER_PASS
				var open := MenuButton.new()
				open.text = "Open"
				open.flat = false
				open.icon = _editor_icon("PackedScene")
				open.tooltip_text = "Open one of its scenes (picked by the %s setting)." % setting
				var paths := []
				for value in scenes:
					open.get_popup().add_item("%s = %s: %s" % [setting, value, scenes[value].get_file()])
					paths.append(scenes[value])
				open.get_popup().index_pressed.connect(func(i): EditorInterface.open_scene_from_path(paths[i]))
				row.add_child(open)
				var del := _comp_button("Remove", "This component switches scenes by the %s setting, so it isn't deleted from here; edit \"components\" in theme.json to change it." % setting, func(): pass)
				del.disabled = true
				row.add_child(del)
		_comp_rows.add_child(row)

func _comp_button(icon_name: String, tooltip: String, callback: Callable) -> Button:
	var button := Button.new()
	button.icon = _editor_icon(icon_name)
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	return button

func _on_component_add(theme: Dictionary, component: String) -> void:
	var json_path: String = theme["path"].path_join("theme.json")
	var old_text := FileAccess.get_file_as_string(json_path)
	var comps = _components_for(theme)
	var new_text: String = comps.create(component, old_text)
	if new_text == "":
		_log_line("[color=#ff786b]Couldn't add %s: %s[/color]" % [component, comps.error])
		return
	var err := _write_json_in_editor(json_path, old_text, new_text)
	if err != OK:
		_log_line("[color=#ff786b]Created the %s files, but couldn't update theme.json (%s).[/color]" % [component, error_string(err)])
	else:
		_log_line("[color=#7ad37a]Added %s: %s[/color]" % [component, theme["path"].path_join(Components.default_relative(component))])
	var note: String = Components.INFO[component].get("note", "")
	if note != "":
		_log_line("  [color=#e0b050]%s[/color]" % note)
	EditorInterface.get_resource_filesystem().scan()
	refresh()

func _on_component_delete(theme: Dictionary, component: String) -> void:
	var comps = _components_for(theme)
	var st: Dictionary = comps.status(component)
	var files: PackedStringArray = comps.files_to_delete(component)
	var open_scenes := EditorInterface.get_open_scenes()
	for path in files:
		if path in open_scenes:
			_comp_delete_dialog.dialog_text = "%s is open in the editor. Close its tab first, then delete the component." % path.get_file()
			_comp_delete_dialog.get_ok_button().hide()
			_comp_pending_delete = ""
			_comp_delete_dialog.popup_centered()
			return
	var label: String = Components.INFO[component]["label"]
	var lines := PackedStringArray()
	if files.is_empty():
		lines.append("Remove %s from theme.json? Its file is already gone." % label)
	else:
		lines.append("Delete the %s component?" % label)
		lines.append("")
		lines.append("These go to the trash:")
		for path in files:
			lines.append("  • %s" % path.trim_prefix(theme["path"] + "/"))
		lines.append("")
		lines.append("Other files in its folder are kept.")
	lines.append("The theme will use Songo Classic's %s instead." % label)
	_comp_delete_dialog.dialog_text = "\n".join(lines)
	_comp_delete_dialog.get_ok_button().show()
	_comp_pending_delete = component
	_comp_delete_dialog.popup_centered()

func _on_component_delete_confirmed() -> void:
	var theme := _selected()
	var component := _comp_pending_delete
	_comp_pending_delete = ""
	if theme.is_empty() or component == "":
		return
	var json_path: String = theme["path"].path_join("theme.json")
	var old_text := FileAccess.get_file_as_string(json_path)
	var comps = _components_for(theme)
	var new_text: String = comps.delete(component, old_text)
	if new_text == "":
		_log_line("[color=#ff786b]Couldn't delete %s: %s[/color]" % [component, comps.error])
	else:
		var err := _write_json_in_editor(json_path, old_text, new_text)
		if err != OK:
			_log_line("[color=#ff786b]Deleted the %s files, but couldn't update theme.json (%s).[/color]" % [component, error_string(err)])
		else:
			_log_line("[color=#7ad37a]Deleted %s; the theme now uses Songo Classic's.[/color]" % component)
	EditorInterface.get_resource_filesystem().scan()
	refresh()

func _on_meta_toggled(expanded: bool) -> void:
	_meta_box.visible = expanded
	_meta_toggle.icon = _editor_icon("GuiTreeArrowDown" if expanded else "GuiTreeArrowRight")

# Fills the fields from the theme's theme.json. Any change still waiting to
# autosave is saved first; force reloads the same theme (the refresh button).
func _load_meta(theme: Dictionary, force := false) -> void:
	var path: String = "" if theme.is_empty() else theme["path"].path_join("theme.json")
	if path == _meta_path and not force:
		return
	_flush_meta()
	_meta_path = path

	var data := {}
	if path != "" and FileAccess.file_exists(path):
		data = ThemeJson.parse(FileAccess.get_file_as_string(path))

	_meta_loading = true
	for key in _meta_fields:
		_meta_fields[key].text = str(data.get(key, ""))
	_meta_description.text = str(data.get("description", ""))
	for key in _meta_lists:
		_meta_lists[key].set_values(_as_string_list(data.get(key)))
	_meta_ai_usage_note = ""
	var ai_usage := AI_USAGE_NOT_SET
	if data.has("ai_usage"):
		var raw = data["ai_usage"]
		if (raw is float or raw is int) and raw == floorf(raw) and raw >= AI_USAGE_MIN and raw <= AI_USAGE_MAX:
			ai_usage = int(raw)
		else:
			_meta_ai_usage_note = "theme.json has ai_usage = %s, which isn't a whole number from %d to %d. Pick a value to replace it." % [JSON.stringify(raw), AI_USAGE_MIN, AI_USAGE_MAX]
	_meta_ai_usage.select(_meta_ai_usage.get_item_index(ai_usage))
	_meta_root_dir.text = str(data.get("rootDir", "(none)"))
	_show_preview()
	_meta_loading = false

	var editable := not data.is_empty()
	for key in _meta_fields:
		_meta_fields[key].editable = editable
	_meta_description.editable = editable
	for key in _meta_lists:
		_meta_lists[key].set_editable(editable)
	_meta_ai_usage.disabled = not editable
	_meta_loaded = _meta_values() if editable else {}
	_meta_original = _meta_loaded.duplicate()
	_meta_saved_once = false
	_on_meta_changed()
	if path != "" and not editable:
		_set_meta_status("theme.json didn't parse, so it can't be edited here. Fix it by hand first.", true)

func _meta_values() -> Dictionary:
	var values := {}
	for key in _meta_fields:
		values[key] = _meta_fields[key].text.strip_edges()
	values["description"] = _meta_description.text.strip_edges()
	for key in _meta_lists:
		values[key] = _meta_lists[key].get_values()
	values["ai_usage"] = _meta_ai_usage.get_selected_id()
	return values

# A theme.json array of strings, or a hand-written "a, b" string, as a list.
func _as_string_list(value) -> PackedStringArray:
	var out := PackedStringArray()
	var items: Array = []
	if value is Array:
		items = value
	elif value is String:
		items = Array(value.split(",", false))
	for item in items:
		var s := str(item).strip_edges()
		if s != "" and not s in out:
			out.append(s)
	return out

func _meta_changed_keys() -> Array:
	if _meta_loaded.is_empty():
		return []
	var values := _meta_values()
	return values.keys().filter(func(k): return var_to_str(values[k]) != var_to_str(_meta_loaded[k]))

func _meta_is_dirty() -> bool:
	return not _meta_changed_keys().is_empty()

func _on_meta_changed() -> void:
	if _meta_loading:
		return
	var changed := _meta_changed_keys()
	var error := _meta_error()
	if error != "":
		_meta_timer.stop()
		_set_meta_status(error + " Changes are saved once it's fixed.", true)
		return
	var warnings := PackedStringArray()
	if _meta_ai_usage_note != "" and not "ai_usage" in changed:
		warnings.append(_meta_ai_usage_note)
	var values := _meta_values()
	if not _meta_original.is_empty() and (values["name"] != _meta_original["name"] or values["version"] != _meta_original["version"]):
		warnings.append("Changing the name or version starts players' saved settings for this theme fresh.")
	if not changed.is_empty():
		_meta_timer.start()
		_set_meta_status(" ".join(warnings + PackedStringArray(["Saving…"])), false, warnings.is_empty())
	elif _meta_saved_once:
		_set_meta_status(" ".join(warnings + PackedStringArray(["Saved."])), false, warnings.is_empty())
	else:
		_set_meta_status(" ".join(warnings), false)

func _meta_error() -> String:
	if _meta_loaded.is_empty():
		return ""
	if _meta_fields["name"].text.strip_edges() == "":
		return "Name can't be empty."
	if _meta_fields["version"].text.strip_edges() == "":
		return "Version can't be empty."
	return ""

func _set_meta_status(text: String, is_error: bool, muted := false) -> void:
	_meta_status.text = text
	_meta_status.visible = text != ""
	if is_error:
		_meta_status.add_theme_color_override("font_color", _editor_color("error_color", Color(1, 0.47, 0.42)))
	elif muted:
		_meta_status.add_theme_color_override("font_color", _editor_color("font_readonly_color", Color(0.65, 0.65, 0.65)))
	else:
		_meta_status.add_theme_color_override("font_color", _editor_color("warning_color", Color(0.88, 0.69, 0.31)))

# Saves a change that's still waiting for the autosave timer, e.g. before
# switching themes. One that can't be saved (an empty name) is dropped, and
# the log says so.
func _flush_meta() -> void:
	if _meta_timer == null or _meta_path == "" or not _meta_is_dirty():
		return
	_meta_timer.stop()
	if _meta_error() == "":
		_save_meta(false)
	else:
		_log_line("[color=#e0b050]theme.json edits for %s weren't saved: %s[/color]" % [_meta_path.get_base_dir().get_file(), _meta_error()])

# Only rewrites the values that changed, in place, so the rest of the file
# (components, settings, formatting) stays exactly as it was. Successful saves
# show in the section's status line rather than the log.
func _save_meta(refresh_after := true) -> void:
	var changed := _meta_changed_keys()
	if changed.is_empty() or _meta_error() != "" or _meta_path == "":
		return
	var text := FileAccess.get_file_as_string(_meta_path)
	if ThemeJson.parse(text).is_empty():
		_log_line("[color=#ff786b]%s no longer parses, so changes here weren't saved. Fix it by hand, then press the refresh button.[/color]" % _meta_path)
		return
	var original := text
	var values := _meta_values()
	for key in changed:
		var after := ""
		var existing := ThemeJson.parse(text)
		for candidate in META_INSERT_AFTER.get(key, []):
			if existing.has(candidate):
				after = candidate
				break
		if key == "ai_usage":
			if values[key] == AI_USAGE_NOT_SET:
				text = ThemeJson.remove_key(text, key)
			else:
				text = ThemeJson.set_int(text, key, values[key], after)
		elif key in _meta_lists:
			text = ThemeJson.set_string_array(text, key, values[key], after)
		else:
			text = ThemeJson.set_string(text, key, values[key], after)
	if ThemeJson.parse(text).is_empty():
		_log_line("[color=#ff786b]Saving would have broken %s; nothing was written.[/color]" % _meta_path)
		return
	var err := _write_json_in_editor(_meta_path, original, text)
	if err != OK:
		_log_line("[color=#ff786b]Couldn't write %s (%s).[/color]" % [_meta_path, error_string(err)])
		return
	_meta_loaded = values
	_meta_saved_once = true
	_on_meta_changed()
	# The list shows names and pack status, both of which may have changed.
	if refresh_after:
		refresh()

# ---- Actions ----

func _on_pack_pressed() -> void:
	var theme := _selected()
	if theme.is_empty() or not theme["external"]:
		return
	var fs := EditorInterface.get_resource_filesystem()
	if fs.is_scanning():
		_log_line("[color=#e0b050]The editor is still scanning/importing. Try again when it's done.[/color]")
		return
	if not ResourceLoader.exists(PACKER_SCRIPT) and not FileAccess.file_exists(PACKER_SCRIPT):
		_log_line("[color=#ff786b]Packer script not found at %s.[/color]" % PACKER_SCRIPT)
		return

	# Unsaved edits wouldn't be in the pck otherwise.
	EditorInterface.save_all_scenes()
	_log_line("Packing [b]%s[/b]…" % theme["dir_name"])
	var packer = load(PACKER_SCRIPT).new()
	var ok: bool = packer.pack_theme(theme["dir_name"])
	if ok:
		_log_line("[color=#7ad37a]Packed %s → %s and %s[/color]" % [theme["dir_name"], PACKAGED_DIR.path_join(theme["dir_name"]), MIRROR_DIR.path_join(theme["dir_name"])])
	else:
		_log_line("[color=#ff786b]Packing %s failed. See the Output panel for details.[/color]" % theme["dir_name"])
	_update_info()

func _on_show_pressed() -> void:
	var theme := _selected()
	if not theme.is_empty():
		EditorInterface.get_file_system_dock().navigate_to_path(theme["path"].path_join("theme.json"))

func _on_open_output_pressed() -> void:
	var path := ProjectSettings.globalize_path(MIRROR_DIR)
	DirAccess.make_dir_recursive_absolute(path)
	OS.shell_open(path)

func _on_duplicate_pressed() -> void:
	var theme := _selected()
	if theme.is_empty():
		return
	_dup_source_label.text = "Copy of: %s (%s)" % [theme["name"], theme["path"]]
	var base_folder := "%sCopy" % theme["dir_name"]
	var folder := base_folder
	var n := 2
	while Duplicator.folder_name_taken(folder):
		folder = "%s%d" % [base_folder, n]
		n += 1
	_dup_folder.text = folder
	_dup_name.text = "%s Copy" % theme["name"]
	_validate_duplicate()
	_dup_dialog.popup_centered()
	_dup_folder.grab_focus()
	_dup_folder.select_all()

func _validate_duplicate() -> void:
	var folder := _dup_folder.text.strip_edges()
	var error := ""
	if folder.is_empty():
		error = "Enter a folder name."
	elif not Duplicator.is_valid_folder_name(folder):
		error = "Use letters, numbers, - or _ (starting with a letter or number)."
	elif Duplicator.folder_name_taken(folder):
		error = "A theme folder named %s already exists." % folder
	elif _dup_name.text.strip_edges().is_empty():
		error = "Enter a display name."
	_dup_error.text = error
	_dup_error.visible = error != ""
	_dup_dialog.get_ok_button().disabled = error != ""

func _on_duplicate_confirmed() -> void:
	var theme := _selected()
	if theme.is_empty() or _dup_dialog.get_ok_button().disabled:
		return
	var folder := _dup_folder.text.strip_edges()
	var display_name := _dup_name.text.strip_edges()

	# Saved first so the copy includes edits still open in the editor.
	EditorInterface.save_all_scenes()
	var duplicator := Duplicator.new()
	var ok := duplicator.duplicate_theme(theme["path"], folder, display_name)
	if not ok:
		_log_line("[color=#ff786b]Duplicate failed: %s[/color]" % "; ".join(duplicator.warnings))
		if duplicator.destination != "" and DirAccess.dir_exists_absolute(duplicator.destination) and duplicator.copied_files > 0:
			_log_line("[color=#e0b050]A partial copy was left at %s. Delete it before retrying.[/color]" % duplicator.destination)
		return

	_log_line("[color=#7ad37a]Duplicated %s → %s (%d files).[/color]" % [theme["dir_name"], duplicator.destination, duplicator.copied_files])
	for old_name in duplicator.renamed_classes:
		_log_line("  class_name %s → %s" % [old_name, duplicator.renamed_classes[old_name]])
	for warning in duplicator.warnings:
		_log_line("  [color=#e0b050]%s[/color]" % warning)

	_show_new_theme(duplicator.destination)

# Rescans so the editor imports the new files, then selects the theme in the
# dock and the FileSystem dock.
func _show_new_theme(path: String) -> void:
	EditorInterface.get_resource_filesystem().scan()
	refresh()
	for idx in _picker.item_count:
		var meta = _picker.get_item_metadata(idx)
		if typeof(meta) == TYPE_INT and _themes[meta]["path"] == path:
			_picker.select(idx)
			_update_info()
			break
	EditorInterface.get_file_system_dock().navigate_to_path(path.path_join("theme.json"))

# ---- New theme ----

func _build_new_theme_dialog() -> void:
	_new_dialog = ConfirmationDialog.new()
	_new_dialog.title = "New Songo Theme"
	_new_dialog.ok_button_text = "Create"
	_new_dialog.confirmed.connect(_on_new_theme_confirmed)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	box.add_child(_make_label("Theme name:"))
	_new_name = LineEdit.new()
	_new_name.placeholder_text = "My Theme"
	_new_name.text_changed.connect(func(_t): _validate_new_theme())
	box.add_child(_new_name)
	_new_folder_label = Label.new()
	_new_folder_label.add_theme_color_override("font_color", _editor_color("font_readonly_color", Color(0.6, 0.6, 0.6)))
	box.add_child(_new_folder_label)
	_new_error = Label.new()
	_new_error.add_theme_color_override("font_color", _editor_color("error_color", Color(1, 0.47, 0.42)))
	_new_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_new_error)

	_new_dialog.add_child(box)
	_new_dialog.register_text_enter(_new_name)
	add_child(_new_dialog)

func _on_new_theme_pressed() -> void:
	_new_name.text = ""
	_validate_new_theme()
	_new_dialog.popup_centered()
	_new_name.grab_focus()

func _validate_new_theme() -> void:
	var display_name := _new_name.text.strip_edges()
	var folder := Scaffold.folder_name_for(display_name)
	_new_folder_label.text = "Folder and rootDir: %s" % (folder if folder != "" else "—")
	var error := ""
	if display_name.is_empty():
		error = "Enter a name."
	elif folder.is_empty():
		error = "The name needs at least one letter or number."
	elif Duplicator.folder_name_taken(folder):
		error = "A theme folder named %s already exists." % folder
	_new_error.text = error
	_new_error.visible = error != "" and not display_name.is_empty()
	_new_dialog.get_ok_button().disabled = error != ""

func _on_new_theme_confirmed() -> void:
	if _new_dialog.get_ok_button().disabled:
		return
	var scaffold := Scaffold.new()
	if not scaffold.create_theme(_new_name.text):
		_log_line("[color=#ff786b]New theme failed: %s[/color]" % scaffold.error)
		return
	_log_line("[color=#7ad37a]Created %s at %s.[/color]" % [_new_name.text.strip_edges(), scaffold.destination])
	_log_line("  Its components use Songo Classic's until you add your own; see its README.md.")
	_show_new_theme(scaffold.destination)

# ---- Writing theme.json ----

# When theme.json has been loaded by the editor (e.g. it's open in the script
# editor), saves it through that resource, the way the editor saves it, which
# updates the resource's modified time so the editor doesn't ask to reload a
# file it already has. The JSON saver writes the text as given, so formatting is
# kept. An open tab showing the old text is refreshed to the new text; one with
# unsaved edits of its own is left alone.
func _write_json_in_editor(path: String, old_text: String, new_text: String) -> Error:
	var err := OK
	var cached = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) if ResourceLoader.has_cached(path) else null
	if cached is JSON:
		cached.parse(new_text, true)
		err = ResourceSaver.save(cached, path)
		if err == OK:
			_refresh_open_text_tabs(old_text, new_text)
	else:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
		file.store_string(new_text)
		file.close()
	if err == OK:
		EditorInterface.get_resource_filesystem().update_file(path)
	return err

# Mirrors TextEditor::reload_text: swap the text, keep caret and scroll, and
# mark it saved so the tab isn't flagged as modified.
func _refresh_open_text_tabs(old_text: String, new_text: String) -> void:
	for editor in EditorInterface.get_script_editor().get_open_script_editors():
		var code := editor.get_base_editor() as TextEdit
		if code == null or code.text != old_text:
			continue
		var line := code.get_caret_line()
		var column := code.get_caret_column()
		var h_scroll := code.scroll_horizontal
		var v_scroll := code.scroll_vertical
		code.text = new_text
		code.set_caret_line(mini(line, code.get_line_count() - 1))
		code.set_caret_column(column)
		code.scroll_horizontal = h_scroll
		code.scroll_vertical = v_scroll
		code.tag_saved_version()

func _log_line(text: String) -> void:
	_log.append_text(text + "\n")
	print_rich(text)
