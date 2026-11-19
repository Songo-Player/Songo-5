@tool
extends Window

# Editor window for a theme's "settings" block in theme.json: the options
# players get under Settings > UI & Customization when the theme is selected.
#
# Left: the settings, in the order players see them. Right: the selected
# setting, in sections: a preview of how it looks in Songo, its name and key,
# its type and options, when it's shown, and which components use it. The JSON
# details (values/labels arrays, visible_when, dependents) are handled by
# settings_model.gd; this file is only the UI.

signal saved

const Model := preload("settings_model.gd")
const ThemeJson := preload("theme_json.gd")

const KIND_ICONS := {
	Model.KIND_TOGGLE: "bool",
	Model.KIND_TEXT: "String",
	Model.KIND_NUMBER: "float",
	Model.KIND_COLOR: "Color",
}
const VALUE_HEADERS := {
	Model.KIND_TEXT: "Stored value",
	Model.KIND_NUMBER: "Number",
	Model.KIND_COLOR: "Color",
}

var model := Model.new()
var json_path := ""
var theme_name := ""
# (path: String, old_text: String, new_text: String) -> Error
var write_json: Callable

var _loaded_text := ""
var _selected := -1
var _overwrite_armed := false

var _header: Label
var _list: ItemList
var _add_menu: MenuButton
var _dup_button: Button
var _up_button: Button
var _down_button: Button
var _delete_button: Button
var _detail: VBoxContainer
var _status: Label
var _save_button: Button
var _revert_button: Button
var _discard_dialog: ConfirmationDialog
var _delete_dialog: ConfirmationDialog

# Parts of the detail panel refreshed while typing (the rest is rebuilt only
# on structural changes, so text fields keep focus).
var _preview: RichTextLabel       # notes under the preview (conditions)
var _preview_host: VBoxContainer  # the app's own setting rows
# Which option each previewed setting is showing, so clicking through the
# preview survives edits; reset when another setting is selected.
var _preview_state := {}
var _preview_theme: Theme
var _issues: RichTextLabel
var _code_label: Label
var _key_edit: LineEdit
var _name_edit: LineEdit

func _init() -> void:
	title = "Theme Settings"
	size = Vector2i(1000, 660)
	min_size = Vector2i(760, 480)
	transient = true
	exclusive = false
	visible = false
	wrap_controls = false
	close_requested.connect(_on_close_requested)

func _ready() -> void:
	_build_ui()

# ---- Opening ----

func is_dirty() -> bool:
	return model.is_dirty()

# Opens the window on a theme. select_key picks a setting; add_kind (an index
# into Model.KINDS) adds a new setting of that type. When the window is
# already open on this theme it isn't reloaded, so unsaved edits survive.
func open_for(theme_dir: String, display_name: String, writer: Callable, select_key := "", add_kind := -1) -> void:
	var path := theme_dir.path_join("theme.json")
	var already_open := visible and path == json_path
	json_path = path
	theme_name = display_name
	write_json = writer
	title = "Theme Settings: %s" % display_name
	_header.text = "%s settings" % display_name
	if not already_open:
		_reload(select_key)
	elif select_key != "":
		select_setting(select_key)
	if not visible:
		popup_centered()
	grab_focus()
	if add_kind >= 0:
		_on_add_kind(add_kind)

func select_setting(key: String) -> void:
	for i in model.entries.size():
		if model.entries[i]["key"] == key:
			_commit_pending_edits()
			_selected = i
			_list.select(i)
			_list.ensure_current_is_visible()
			_rebuild_detail()
			_update_list_buttons()
			return

func _reload(keep_key: String) -> void:
	_overwrite_armed = false
	_loaded_text = FileAccess.get_file_as_string(json_path)
	model.load_from_text(_loaded_text)
	model.mark_loaded()
	_selected = -1
	for i in model.entries.size():
		if model.entries[i]["key"] == keep_key:
			_selected = i
	if _selected < 0 and not model.entries.is_empty():
		_selected = 0
	_rebuild_list()
	_rebuild_detail()
	_update_footer()

# ---- Layout ----

func _build_ui() -> void:
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style := _editor_stylebox("panel", "AcceptDialog")
	if bg_style:
		background.add_theme_stylebox_override("panel", bg_style)
	add_child(background)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	background.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 18)
	root.add_child(_header)
	root.add_child(_hint("Players find these under Settings → UI & Customization while this theme is selected, in the order listed here. Settings that are only shown in some cases appear tucked under the setting they depend on."))

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 40
	root.add_child(split)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 260
	split.add_child(left)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_list_selected)
	left.add_child(_list)
	var list_buttons := HBoxContainer.new()
	left.add_child(list_buttons)
	_add_menu = MenuButton.new()
	_add_menu.text = "Add"
	_add_menu.flat = false
	_add_menu.icon = _icon("Add")
	_add_menu.tooltip_text = "Add a setting after the selected one."
	var popup := _add_menu.get_popup()
	for i in Model.KINDS.size():
		var kind: String = Model.KINDS[i]
		popup.add_icon_item(_icon(KIND_ICONS[kind]), Model.KIND_NAMES[kind], i)
		popup.set_item_tooltip(i, Model.KIND_HINTS[kind])
	popup.id_pressed.connect(_on_add_kind)
	list_buttons.add_child(_add_menu)
	list_buttons.add_child(_spacer())
	_dup_button = _icon_button("Duplicate", "Duplicate the selected setting.", _on_duplicate)
	_up_button = _icon_button("MoveUp", "Move up (players see settings in this order).", func(): _move(-1))
	_down_button = _icon_button("MoveDown", "Move down.", func(): _move(1))
	_delete_button = _icon_button("Remove", "Delete the selected setting.", _on_delete)
	for b in [_dup_button, _up_button, _down_button, _delete_button]:
		list_buttons.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)
	var detail_margin := MarginContainer.new()
	detail_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_margin.add_theme_constant_override("margin_left", 8)
	detail_margin.add_theme_constant_override("margin_right", 12)
	scroll.add_child(detail_margin)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 6)
	detail_margin.add_child(_detail)

	root.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	root.add_child(footer)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(_status)
	_revert_button = Button.new()
	_revert_button.text = "Revert"
	_revert_button.icon = _icon("Reload")
	_revert_button.tooltip_text = "Throw away changes made here and reload the settings from theme.json."
	_revert_button.pressed.connect(func(): _reload(_selected_key()))
	footer.add_child(_revert_button)
	_save_button = Button.new()
	_save_button.text = "Save to theme.json"
	_save_button.icon = _icon("Save")
	_save_button.pressed.connect(_on_save)
	footer.add_child(_save_button)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(_on_close_requested)
	footer.add_child(close)

	_discard_dialog = ConfirmationDialog.new()
	_discard_dialog.title = "Unsaved settings"
	_discard_dialog.dialog_text = "Close without saving your changes to these settings?"
	_discard_dialog.ok_button_text = "Discard changes"
	_discard_dialog.confirmed.connect(func():
		_reload(_selected_key())
		hide())
	add_child(_discard_dialog)

	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Delete setting"
	_delete_dialog.ok_button_text = "Delete"
	_delete_dialog.confirmed.connect(_delete_selected)
	add_child(_delete_dialog)

# ---- List ----

func _rebuild_list() -> void:
	_list.clear()
	for i in model.entries.size():
		_list.add_item("")
		_update_list_item(i)
	if _selected >= 0 and _selected < _list.item_count:
		_list.select(_selected)
		_list.ensure_current_is_visible()
	_update_list_buttons()

func _update_list_item(i: int) -> void:
	if i < 0 or i >= _list.item_count:
		return
	var entry: Dictionary = model.entries[i]
	var issues := model.issues(entry)
	var name := str(entry["data"].get("display_name", "")).strip_edges()
	if name == "":
		name = entry["key"] if entry["key"] != "" else "(unnamed)"
	var conditional: bool = entry["data"].get("visible_when") is Dictionary and not entry["data"]["visible_when"].is_empty()
	_list.set_item_text(i, "%s%s%s" % ["↳ " if conditional else "", name, "  •" if entry["dirty"] else ""])
	var icon_name: String = KIND_ICONS[entry["kind"]]
	var tip := "%s\nKey: %s" % [Model.KIND_NAMES[entry["kind"]], entry["key"]]
	if not issues["errors"].is_empty():
		icon_name = "StatusError"
		tip += "\n\nNeeds fixing:\n• " + "\n• ".join(issues["errors"])
	elif not issues["warnings"].is_empty():
		icon_name = "StatusWarning"
		tip += "\n\n• " + "\n• ".join(issues["warnings"])
	if entry["dirty"]:
		tip += "\n\nChanged (not saved yet)."
	_list.set_item_icon(i, _icon(icon_name))
	_list.set_item_tooltip(i, tip)

func _update_list_buttons() -> void:
	var has := _selected >= 0 and _selected < model.entries.size()
	_dup_button.disabled = not has
	_delete_button.disabled = not has
	_up_button.disabled = not has or _selected == 0
	_down_button.disabled = not has or _selected == model.entries.size() - 1
	_add_menu.disabled = model.error != ""

func _selected_entry():
	return model.entries[_selected] if _selected >= 0 and _selected < model.entries.size() else null

func _selected_key() -> String:
	var entry = _selected_entry()
	return entry["key"] if entry else ""

func _on_list_selected(index: int) -> void:
	_commit_pending_edits()
	_selected = index
	_list.select(index)
	_rebuild_detail()
	_update_list_buttons()

func _on_add_kind(id: int) -> void:
	_commit_pending_edits()
	var entry := model.add_setting(Model.KINDS[id], _selected + 1)
	_selected = model.entries.find(entry)
	_rebuild_list()
	_rebuild_detail()
	_update_footer()
	if _name_edit:
		_name_edit.grab_focus.call_deferred()
		_name_edit.select_all.call_deferred()

func _on_duplicate() -> void:
	if _selected < 0:
		return
	_commit_pending_edits()
	var entry := model.duplicate_setting(_selected)
	_selected = model.entries.find(entry)
	_rebuild_list()
	_rebuild_detail()
	_update_footer()

func _move(delta: int) -> void:
	if _selected < 0:
		return
	_commit_pending_edits()
	_selected = model.move_setting(_selected, delta)
	_rebuild_list()
	_update_footer()

func _on_delete() -> void:
	var entry = _selected_entry()
	if entry == null:
		return
	var dependents := model.settings_depending_on(entry["key"])
	if dependents.is_empty():
		_delete_selected()
		return
	var names := PackedStringArray(dependents.map(func(e): return str(e["data"].get("display_name", e["key"]))))
	_delete_dialog.dialog_text = "Delete \"%s\"?\n\nThese settings are only shown depending on it, and will always be shown instead:\n• %s" % [entry["data"].get("display_name", entry["key"]), "\n• ".join(names)]
	_delete_dialog.popup_centered()

func _delete_selected() -> void:
	if _selected < 0:
		return
	model.remove_setting(_selected)
	_selected = mini(_selected, model.entries.size() - 1)
	_rebuild_list()
	_rebuild_detail()
	_update_footer()

# ---- Detail panel ----

func _rebuild_detail() -> void:
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	_preview = null
	_preview_host = null
	_preview_state.clear()
	_issues = null
	_code_label = null
	_key_edit = null
	_name_edit = null

	if model.error != "":
		_detail.add_child(_error_label(model.error))
		return
	var entry = _selected_entry()
	if entry == null:
		var empty := _hint("This theme has no settings yet. Use Add to create one: a toggle, a list of named options, numbers or colors.")
		_detail.add_child(empty)
		return

	_preview = _rich()
	_detail.add_child(_section_title("In Songo"))
	_preview_host = VBoxContainer.new()
	_detail.add_child(_preview_host)
	_detail.add_child(_preview)
	_issues = _rich()
	_detail.add_child(_issues)

	_build_basics(entry)
	_build_type_and_options(entry)
	_build_conditions(entry)
	_build_dependents(entry)
	_refresh_light()

func _build_basics(entry: Dictionary) -> void:
	_detail.add_child(_section_title("Name"))
	var grid := _grid()
	_detail.add_child(grid)

	_name_edit = LineEdit.new()
	_name_edit.text = str(entry["data"].get("display_name", ""))
	_name_edit.placeholder_text = "e.g. Background Color"
	_name_edit.text_changed.connect(func(t):
		entry["data"]["display_name"] = t
		if entry["key_auto"]:
			entry["key"] = model.unique_key(Model.slug(t), entry)
			_key_edit.text = entry["key"]
		_changed(entry))
	_name_edit.focus_exited.connect(func(): _commit_key(entry))
	_grid_row(grid, "Shown as", _name_edit, "What players see in the settings list.")

	var description := TextEdit.new()
	description.text = str(entry["data"].get("description", ""))
	description.placeholder_text = "Optional. Shown under the name, e.g. what it changes."
	description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	description.custom_minimum_size.y = 58
	description.scroll_fit_content_height = true
	description.text_changed.connect(func():
		entry["data"]["description"] = description.text
		_changed(entry))
	_grid_row(grid, "Description", description)

	_key_edit = LineEdit.new()
	_key_edit.text = entry["key"]
	_key_edit.placeholder_text = "e.g. background_color"
	_key_edit.text_changed.connect(func(t):
		entry["key"] = t.strip_edges()
		entry["key_auto"] = false
		_changed(entry))
	_key_edit.text_submitted.connect(func(_t): _commit_key(entry))
	_key_edit.focus_exited.connect(func(): _commit_key(entry))
	_grid_row(grid, "Key", _key_edit, "The name scripts use to read it. New settings follow the name until you edit this. Renaming one that scripts already use means updating those scripts.")

	var code_row := HBoxContainer.new()
	_code_label = Label.new()
	_code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_label.clip_text = true
	var mono := _editor_font("source")
	if mono:
		_code_label.add_theme_font_override("font", mono)
	_code_label.add_theme_color_override("font_color", _editor_color("font_readonly_color", Color(0.7, 0.7, 0.7)))
	code_row.add_child(_code_label)
	var copy := Button.new()
	copy.flat = true
	copy.icon = _icon("ActionCopy")
	copy.tooltip_text = "Copy this line for use in a theme script."
	copy.pressed.connect(func(): DisplayServer.clipboard_set(model.code_snippet(entry)))
	code_row.add_child(copy)
	_grid_row(grid, "In scripts", code_row)

func _build_type_and_options(entry: Dictionary) -> void:
	_detail.add_child(_section_title("Type and options"))
	var type_row := HBoxContainer.new()
	var type_pick := OptionButton.new()
	for i in Model.KINDS.size():
		var kind: String = Model.KINDS[i]
		type_pick.add_icon_item(_icon(KIND_ICONS[kind]), Model.KIND_NAMES[kind], i)
	type_pick.select(Model.KINDS.find(entry["kind"]))
	type_pick.item_selected.connect(func(i):
		_commit_pending_edits()
		model.set_kind(entry, Model.KINDS[i])
		_changed(entry)
		_rebuild_detail())
	type_row.add_child(type_pick)
	_detail.add_child(type_row)
	_detail.add_child(_hint(Model.KIND_HINTS[entry["kind"]]))

	if entry["kind"] == Model.KIND_TOGGLE:
		_build_toggle_options(entry)
	else:
		_build_option_rows(entry)

func _build_toggle_options(entry: Dictionary) -> void:
	var data: Dictionary = entry["data"]
	var grid := _grid()
	_detail.add_child(grid)
	var starts := OptionButton.new()
	starts.add_item("On", 0)
	starts.add_item("Off", 1)
	starts.select(0 if _is_true(data.get("default")) else 1)
	starts.item_selected.connect(func(i):
		data["default"] = i == 0
		_changed(entry))
	_grid_row(grid, "Starts", starts, "Where it starts for players who haven't changed it.")

	var labels: Array = data.get("labels", []) if data.get("labels") is Array else []
	var on_edit := LineEdit.new()
	on_edit.placeholder_text = Model.TOGGLE_ON_TEXT
	on_edit.text = str(labels[0]) if labels.size() > 0 and str(labels[0]) != Model.TOGGLE_ON_TEXT else ""
	var off_edit := LineEdit.new()
	off_edit.placeholder_text = Model.TOGGLE_OFF_TEXT
	off_edit.text = str(labels[1]) if labels.size() > 1 and str(labels[1]) != Model.TOGGLE_OFF_TEXT else ""
	var update_labels := func():
		if on_edit.text.strip_edges() == "" and off_edit.text.strip_edges() == "":
			data.erase("labels")
		else:
			data["labels"] = [on_edit.text, off_edit.text]
		_changed(entry)
	on_edit.text_changed.connect(func(_t): update_labels.call())
	off_edit.text_changed.connect(func(_t): update_labels.call())
	_grid_row(grid, "Text when on", on_edit, "Optional. Leave blank and Songo shows \"%s\"." % Model.TOGGLE_ON_TEXT)
	_grid_row(grid, "Text when off", off_edit, "Optional. Leave blank and Songo shows \"%s\"." % Model.TOGGLE_OFF_TEXT)

func _build_option_rows(entry: Dictionary) -> void:
	var data: Dictionary = entry["data"]
	var kind: String = entry["kind"]
	_detail.add_child(_hint("Players step through these in this order. The selected circle is where it starts."))

	var header := HBoxContainer.new()
	header.add_child(_small_label("Start", 40))
	var shown := _small_label("Shown to players", 0)
	shown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(shown)
	var value_header := _small_label(VALUE_HEADERS[kind], 130 if kind != Model.KIND_COLOR else 70)
	header.add_child(value_header)
	header.add_child(_small_label("", 96))
	_detail.add_child(header)

	var group := ButtonGroup.new()
	for i in data["values"].size():
		_detail.add_child(_option_row(entry, i, group))

	var buttons := HBoxContainer.new()
	var add := Button.new()
	add.text = "Add option"
	add.icon = _icon("Add")
	add.pressed.connect(func():
		_commit_pending_edits()
		_add_option(entry)
		_changed(entry)
		_rebuild_detail())
	buttons.add_child(add)
	_detail.add_child(buttons)

	if kind == Model.KIND_NUMBER:
		_build_number_fill(entry, buttons)

func _option_row(entry: Dictionary, i: int, group: ButtonGroup) -> Control:
	var data: Dictionary = entry["data"]
	var kind: String = entry["kind"]
	var values: Array = data["values"]
	var labels: Array = data["labels"]
	var row := HBoxContainer.new()
	var state := {"committed": values[i], "linked": false}

	var start := CheckBox.new()
	start.button_group = group
	start.custom_minimum_size.x = 40
	start.tooltip_text = "Start on this option."
	start.button_pressed = Model._same(data.get("default"), values[i])
	start.toggled.connect(func(on):
		if on:
			data["default"] = values[i]
			_changed(entry))
	row.add_child(start)

	var label_edit := LineEdit.new()
	label_edit.text = str(labels[i])
	label_edit.placeholder_text = "Text players see"
	label_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label_edit)

	var value_control: Control
	var set_value := func(v):
		values[i] = v
		if start.button_pressed:
			data["default"] = v
	var commit := func():
		model.commit_option_value(entry, state["committed"], values[i])
		state["committed"] = values[i]
		_refresh_light()
	match kind:
		Model.KIND_TEXT:
			var value_edit := LineEdit.new()
			value_edit.text = str(values[i])
			value_edit.placeholder_text = "stored_value"
			value_edit.custom_minimum_size.x = 130
			value_edit.tooltip_text = "What scripts get when this option is picked. Follows the text until you edit it."
			state["linked"] = Model.slug(str(labels[i])) == str(values[i])
			value_edit.text_changed.connect(func(t):
				state["linked"] = false
				set_value.call(t)
				_changed(entry))
			value_edit.focus_exited.connect(commit)
			value_edit.text_submitted.connect(func(_t): commit.call())
			label_edit.text_changed.connect(func(t):
				if state["linked"]:
					var v: String = Model.slug(t)
					value_edit.text = v
					set_value.call(v))
			value_control = value_edit
		Model.KIND_NUMBER:
			var number_edit := LineEdit.new()
			number_edit.text = Model.display_value(values[i])
			number_edit.custom_minimum_size.x = 130
			number_edit.tooltip_text = "The number scripts get. Decimals are fine (e.g. 0.8)."
			state["linked"] = str(labels[i]) == Model.display_value(values[i])
			number_edit.text_changed.connect(func(t):
				var valid: bool = t.strip_edges().is_valid_float()
				number_edit.modulate = Color.WHITE if valid else Color(1, 0.55, 0.5)
				set_value.call(float(t) if valid else t)
				if state["linked"] and valid:
					label_edit.text = Model.display_value(float(t))
					labels[i] = label_edit.text
				_changed(entry))
			number_edit.focus_exited.connect(commit)
			number_edit.text_submitted.connect(func(_t): commit.call())
			label_edit.text_changed.connect(func(_t): state["linked"] = false)
			value_control = number_edit
		Model.KIND_COLOR:
			var picker := ColorPickerButton.new()
			var hex := str(values[i]).trim_prefix("#")
			picker.color = Color.html(hex) if Color.html_is_valid(hex) else Color.WHITE
			picker.edit_alpha = hex.length() == 8
			picker.custom_minimum_size = Vector2(70, 0)
			picker.tooltip_text = "#" + hex
			picker.color_changed.connect(func(c):
				var new_hex: String = c.to_html(picker.edit_alpha)
				picker.tooltip_text = "#" + new_hex
				set_value.call(new_hex)
				_changed(entry))
			picker.popup_closed.connect(commit)
			value_control = picker
	row.add_child(value_control)

	label_edit.text_changed.connect(func(t):
		labels[i] = t
		_changed(entry))
	label_edit.focus_exited.connect(commit)

	var up := _icon_button("MoveUp", "Move up", func(): _swap_options(entry, i, i - 1))
	up.disabled = i == 0
	var down := _icon_button("MoveDown", "Move down", func(): _swap_options(entry, i, i + 1))
	down.disabled = i == values.size() - 1
	var remove := _icon_button("Remove", "Remove this option", func():
		_commit_pending_edits()
		model.remove_option(entry, i)
		_changed(entry)
		_rebuild_detail())
	remove.disabled = values.size() <= 2
	if remove.disabled:
		remove.tooltip_text = "A setting needs at least two options."
	for b in [up, down, remove]:
		b.flat = true
		row.add_child(b)
	return row

func _swap_options(entry: Dictionary, a: int, b: int) -> void:
	_commit_pending_edits()
	var data: Dictionary = entry["data"]
	for key in ["values", "labels"]:
		var arr: Array = data[key]
		var tmp = arr[a]
		arr[a] = arr[b]
		arr[b] = tmp
	_changed(entry)
	_rebuild_detail()

func _add_option(entry: Dictionary) -> void:
	var data: Dictionary = entry["data"]
	var values: Array = data["values"]
	var labels: Array = data["labels"]
	match entry["kind"]:
		Model.KIND_TEXT:
			var n := values.size() + 1
			while values.has("option_%d" % n):
				n += 1
			values.append("option_%d" % n)
			labels.append("Option %d" % n)
		Model.KIND_NUMBER:
			var last := float(values[-1]) if not values.is_empty() and (values[-1] is float or values[-1] is int) else 0.0
			var step := last - float(values[-2]) if values.size() >= 2 and (values[-2] is float or values[-2] is int) else 1.0
			if step == 0.0:
				step = 1.0
			values.append(last + step)
			labels.append(Model.display_value(last + step))
		Model.KIND_COLOR:
			values.append("ffffff")
			labels.append("Color %d" % (values.size()))

# "Fill range": replaces the options with from..to by step, labelled with an
# optional suffix (e.g. "x" for scales, "px" for sizes).
func _build_number_fill(entry: Dictionary, buttons: HBoxContainer) -> void:
	var toggle := Button.new()
	toggle.text = "Fill range…"
	toggle.toggle_mode = true
	toggle.tooltip_text = "Replace the options with an evenly spaced range of numbers."
	buttons.add_child(toggle)

	var panel := VBoxContainer.new()
	panel.visible = false
	toggle.toggled.connect(func(on): panel.visible = on)
	var row := HFlowContainer.new()
	var values: Array = entry["data"]["values"]
	var numeric := values.filter(func(v): return v is float or v is int)
	var from := _number_field(Model.display_value(numeric.min()) if not numeric.is_empty() else "1", "From")
	var to := _number_field(Model.display_value(numeric.max()) if not numeric.is_empty() else "5", "To")
	var step := _number_field(Model.display_value(float(numeric[1]) - float(numeric[0])) if numeric.size() >= 2 else "1", "Step")
	var suffix := LineEdit.new()
	suffix.placeholder_text = "e.g. x or px"
	suffix.custom_minimum_size.x = 90
	for pair in [["From", from], ["To", to], ["Step", step], ["Text after number", suffix]]:
		row.add_child(_small_label(pair[0], 0))
		row.add_child(pair[1])
	var fill := Button.new()
	fill.text = "Fill"
	row.add_child(fill)
	panel.add_child(row)
	var error := _error_label("")
	error.visible = false
	panel.add_child(error)
	_detail.add_child(panel)

	fill.pressed.connect(func():
		var problem := ""
		if not (from.text.is_valid_float() and to.text.is_valid_float() and step.text.is_valid_float()):
			problem = "From, To and Step need to be numbers."
		elif float(step.text) <= 0.0:
			problem = "Step needs to be more than 0."
		elif float(to.text) < float(from.text):
			problem = "To needs to be at least From."
		elif (float(to.text) - float(from.text)) / float(step.text) > 200:
			problem = "That's over 200 options; use a bigger step."
		error.text = problem
		error.visible = problem != ""
		if problem != "":
			return
		var new_values := []
		var new_labels := []
		var a := float(from.text)
		var s := float(step.text)
		var count := int(floor((float(to.text) - a) / s + 0.0001)) + 1
		for k in count:
			new_values.append(snappedf(a + s * k, 0.0001))
		# "1.0x" next to "0.75x", like the existing themes write decimal ranges.
		var decimals := Model._uses_decimals(new_values)
		for v in new_values:
			new_labels.append(Model.format_number(v, decimals) + suffix.text)
		var data: Dictionary = entry["data"]
		var old_default = data.get("default")
		# Keeps a matching default; conditions on the old numbers are re-checked.
		data["values"] = new_values
		data["labels"] = new_labels
		if Model._index_of(new_values, old_default) < 0:
			data["default"] = new_values[0]
		_changed(entry)
		_rebuild_detail())

func _number_field(text: String, placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	edit.placeholder_text = placeholder
	edit.custom_minimum_size.x = 64
	return edit

func _build_conditions(entry: Dictionary) -> void:
	_detail.add_child(_section_title("When it's shown"))
	var conditions: Dictionary = entry["data"].get("visible_when", {}) if entry["data"].get("visible_when") is Dictionary else {}
	if conditions.is_empty():
		_detail.add_child(_hint("Always shown. Add a condition to only show it while other settings are set a certain way, e.g. a \"Menu Fit\" setting that only matters for one menu layout."))
	else:
		_detail.add_child(_hint("Only shown while all of these are true:"))

	var candidates := model.condition_candidates(entry)
	for other_key in conditions.keys():
		_detail.add_child(_condition_row(entry, other_key, candidates))

	var add := Button.new()
	add.text = "Add condition"
	add.icon = _icon("Add")
	var unused := candidates.filter(func(e): return not conditions.has(e["key"]))
	add.disabled = unused.is_empty()
	add.tooltip_text = "Only show this setting depending on another one." if not add.disabled else "There are no other settings it could depend on."
	add.pressed.connect(func():
		_commit_pending_edits()
		var other: Dictionary = unused[0]
		model.conditions(entry)[other["key"]] = _starting_values(other)
		_changed(entry)
		_rebuild_detail())
	var row := HBoxContainer.new()
	row.add_child(add)
	_detail.add_child(row)

func _condition_row(entry: Dictionary, other_key: String, candidates: Array) -> Control:
	var conditions: Dictionary = model.conditions(entry)
	var box := VBoxContainer.new()
	var top := HBoxContainer.new()
	box.add_child(top)
	var pick := OptionButton.new()
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var choices := candidates.filter(func(e): return e["key"] == other_key or not conditions.has(e["key"]))
	for e in choices:
		pick.add_icon_item(_icon(KIND_ICONS[e["kind"]]), str(e["data"].get("display_name", e["key"])))
	var current := choices.map(func(e): return e["key"]).find(other_key)
	if current < 0:
		pick.add_item("(no setting \"%s\")" % other_key)
		current = pick.item_count - 1
	pick.select(current)
	pick.item_selected.connect(func(i):
		if i >= choices.size():
			return
		_commit_pending_edits()
		var other: Dictionary = choices[i]
		var rebuilt := {}
		for k in conditions:
			if k == other_key:
				rebuilt[other["key"]] = _starting_values(other)
			else:
				rebuilt[k] = conditions[k]
		entry["data"]["visible_when"] = rebuilt
		_changed(entry)
		_rebuild_detail())
	top.add_child(_small_label("Only when", 0))
	top.add_child(pick)
	top.add_child(_small_label("is one of:", 0))
	var remove := _icon_button("Remove", "Remove this condition", func():
		_commit_pending_edits()
		conditions.erase(other_key)
		model._tidy_conditions(entry)
		_changed(entry)
		_rebuild_detail())
	remove.flat = true
	top.add_child(remove)

	var other := model.find(other_key)
	if other.is_empty():
		return box
	var flow := HFlowContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_child(flow)
	box.add_child(margin)
	var other_values: Array = other["data"].get("values", [])
	var other_labels: Array = other["data"].get("labels", []) if other["data"].get("labels") is Array else []
	for j in other_values.size():
		var v = other_values[j]
		var check := CheckBox.new()
		check.text = _option_label(other, v)
		var wanted = conditions.get(other_key)
		check.button_pressed = wanted is Array and Model._index_of(wanted, v) >= 0
		check.toggled.connect(func(_on):
			# Rebuilt in the other setting's option order.
			var picked := []
			for k in flow.get_child_count():
				if flow.get_child(k).button_pressed:
					picked.append(other_values[k])
			conditions[other_key] = picked
			_changed(entry))
		flow.add_child(check)
	return box

func _build_dependents(entry: Dictionary) -> void:
	_detail.add_child(_section_title("Used by"))
	_detail.add_child(_hint("Tick the theme components whose scripts read this setting. It isn't shown to players; Songo uses it to bring in the right defaults when a theme borrows Songo Classic's components."))
	var data: Dictionary = entry["data"]
	var grid := GridContainer.new()
	grid.columns = 2
	for component in Model.COMPONENTS:
		var check := CheckBox.new()
		check.text = component.replace("_", " ").capitalize()
		check.tooltip_text = component
		check.button_pressed = data.get("dependents", []) is Array and component in data.get("dependents", [])
		check.toggled.connect(func(on):
			var deps: Array = data.get("dependents", []) if data.get("dependents") is Array else []
			# Known components in a stable order; anything else listed is kept.
			var others := deps.filter(func(d): return not d in Model.COMPONENTS)
			var picked := Model.COMPONENTS.filter(func(c): return (c == component and on) or (c != component and c in deps))
			data["dependents"] = picked + others
			_changed(entry))
		grid.add_child(check)
	_detail.add_child(grid)
	var switches := model.component_switches(entry["key"])
	for component in switches:
		_detail.add_child(_hint("theme.json's %s component picks its scene from this setting (scenes for: %s)." % [component, ", ".join(PackedStringArray(switches[component]))]))
	var extra := data.keys().filter(func(k): return not k in Model.KEY_ORDER)
	if not extra.is_empty():
		_detail.add_child(_hint("Also has %s in theme.json; kept as is." % ", ".join(PackedStringArray(extra))))

# ---- Refreshing ----

# Something in the entry changed: mark it, and refresh what depends on it
# without rebuilding the fields being typed in.
func _changed(entry: Dictionary) -> void:
	entry["dirty"] = true
	_refresh_light()

func _refresh_light() -> void:
	var entry = _selected_entry()
	if entry == null:
		_update_footer()
		return
	if _preview_host:
		var rendered := _render_app_preview(entry)
		_preview.text = _preview_note(entry) if rendered else _preview_text(entry)
	elif _preview:
		_preview.text = _preview_text(entry)
	if _issues:
		var issues := model.issues(entry)
		var lines := PackedStringArray()
		for e in issues["errors"]:
			lines.append("[color=#ff786b]● %s[/color]" % _escape(e))
		for w in issues["warnings"]:
			lines.append("[color=#e0b050]● %s[/color]" % _escape(w))
		_issues.text = "\n".join(lines)
		_issues.visible = not lines.is_empty()
	if _code_label:
		_code_label.text = model.code_snippet(entry)
		_code_label.tooltip_text = _code_label.text
	for i in model.entries.size():
		_update_list_item(i)
	_update_footer()

# ---- App preview ----
# The setting rendered with the app's own setting_line_item.tscn, inside the
# same panels, styles and theme as Settings > UI & Customization, at the app's
# 640x480 pixel size. The scene's scripts aren't tool scripts (and expect the
# app's autoloads), so they're removed from the preview copy and its nodes set
# up the way setting_line_item.gd's setup()/_ready() would. The arrows and swap
# button work, cycling what the preview shows (not the default).

const APP_LINE_ITEM := "res://scenes/settings_container/sub_containers/ui_and_customization/setting_line_item/setting_line_item.tscn"
const APP_SECTION_STYLE := "res://scenes/settings_container/settings_container_section.tres"
const APP_BASE_THEME := "res://assets/songo_base_theme.tres"
const APP_TAIL_TEXTURE := "res://assets/folder_nested_line_long.png"
# From setting_line_item.gd.
const APP_DEPENDENT_INSET := 28
const APP_TAIL_OFFSET_X := 6 - APP_DEPENDENT_INSET
# Width of the theme settings list in the 640px-wide app, after the content
# margin and the settings page's own margins.
const APP_LIST_WIDTH := 556

# Returns false if the app's scenes can't be loaded (the caller falls back to
# a text preview).
func _render_app_preview(entry: Dictionary) -> bool:
	for child in _preview_host.get_children():
		_preview_host.remove_child(child)
		child.queue_free()
	if not (ResourceLoader.exists(APP_LINE_ITEM) and ResourceLoader.exists(APP_BASE_THEME)):
		return false

	# Outer section panel (a plain PanelContainer in the app) and the darker
	# theme settings panel inside it, with the page's margins.
	var outer := PanelContainer.new()
	outer.theme = _app_theme()
	outer.custom_minimum_size.x = APP_LIST_WIDTH + 32
	outer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color(0.05, 0.05, 0.06)
	outer.add_theme_stylebox_override("panel", backdrop)
	var outer_margin := _margin(8)
	outer.add_child(outer_margin)
	var section := PanelContainer.new()
	if ResourceLoader.exists(APP_SECTION_STYLE):
		section.add_theme_stylebox_override("panel", load(APP_SECTION_STYLE))
	outer_margin.add_child(section)
	var inner_margin := _margin(8)
	section.add_child(inner_margin)
	var items := VBoxContainer.new()
	items.add_theme_constant_override("separation", 8)
	inner_margin.add_child(items)

	# A conditional setting is shown under the setting it depends on, like the
	# app does (ThemeManager.get_setting_parent: the last one listed).
	var parent := _app_parent(entry)
	var rows := []
	if not parent.is_empty():
		rows.append([parent, 0])
	rows.append([entry, 1 if not parent.is_empty() else 0])
	var built := {}
	for row in rows:
		var item := _app_line_item(row[0], row[1])
		items.add_child(item)
		built[row[0]["key"]] = item
	if not parent.is_empty():
		var child_item: Control = built[entry["key"]]
		var parent_item: Control = built[parent["key"]]
		child_item.visible = _app_conditions_met(entry)
		items.sort_children.connect(func(): _app_tail_reach(child_item, parent_item))
	_preview_host.add_child(outer)
	return true

# Default theme with the app's base theme over it, as the app's root theme is.
# Settings rows use the SongoSettings* type variations, which the base theme
# defines fully, so a theme's own styles don't reach them in the app either.
func _app_theme() -> Theme:
	if _preview_theme == null:
		_preview_theme = ThemeDB.get_default_theme().duplicate()
		_preview_theme.merge_with(load(APP_BASE_THEME))
	return _preview_theme

func _app_parent(entry: Dictionary) -> Dictionary:
	var conditions = entry["data"].get("visible_when")
	if not conditions is Dictionary:
		return {}
	var parent := {}
	for e in model.entries:
		if e != entry and conditions.has(e["key"]):
			parent = e
	return parent

# Whether the app would show the entry given what the preview's other rows
# show (or their defaults).
func _app_conditions_met(entry: Dictionary) -> bool:
	var conditions: Dictionary = entry["data"].get("visible_when", {})
	for k in conditions:
		var other := model.find(k)
		if other.is_empty() or not conditions[k] is Array:
			continue
		if Model._index_of(conditions[k], _app_value(other)) < 0:
			return false
	return true

func _app_index(entry: Dictionary) -> int:
	var values: Array = entry["data"].get("values", []) if entry["data"].get("values") is Array else []
	var i: int = _preview_state.get(entry["key"], Model._index_of(values, entry["data"].get("default")))
	return clampi(i, 0, maxi(values.size() - 1, 0))

func _app_value(entry: Dictionary):
	var values: Array = entry["data"].get("values", [])
	return values[_app_index(entry)] if not values.is_empty() else null

func _app_line_item(entry: Dictionary, depth: int) -> Control:
	var item: Control = load(APP_LINE_ITEM).instantiate()
	_strip_scripts(item)
	var data: Dictionary = entry["data"]
	var values: Array = data.get("values", []) if data.get("values") is Array else []
	var labels: Array = data.get("labels", []) if data.get("labels") is Array else []

	var name := str(data.get("display_name", ""))
	item.get_node("%SettingLabel").text = name if data.has("display_name") else "Setting"
	if data.has("description") and str(data["description"]).strip_edges() != "":
		item.get_node("%SettingDescription").visible = true
		item.get_node("%SettingDescription").text = str(data["description"])

	var is_bool: bool = values.size() == 2 and values.all(func(v): return v is bool) and values[0] != values[1]
	if is_bool:
		var swap: Button = item.get_node("%BoolSwapButton")
		var on_label: Label = item.get_node("%SettingValueTrueLabel")
		var off_label: Label = item.get_node("%SettingValueFalseLabel")
		swap.show()
		if labels.size() >= 2:
			on_label.text = str(labels[0])
			off_label.text = str(labels[1])
		var show_value := func():
			var on := _is_true(_app_value(entry))
			on_label.visible = on
			off_label.visible = not on
			if data.get("button_text") is Array and data["button_text"].size() >= 2:
				swap.text = str(data["button_text"][0 if on else 1])
			elif data.get("button_text") is String:
				swap.text = data["button_text"]
		show_value.call()
		swap.pressed.connect(func():
			_preview_state[entry["key"]] = 1 - _app_index(entry)
			_refresh_light.call_deferred())
	elif values.size() > 1:
		item.get_node("%PrevNextContainer").show()
		var value_label: LineEdit = item.get_node("%SettingValueLabel")
		var i := _app_index(entry)
		if i < labels.size():
			value_label.show()
			value_label.text = str(labels[i])
		var prev: Button = item.get_node("%PrevNextContainer/PrevValueButton")
		var next: Button = item.get_node("%PrevNextContainer/NextValueButton")
		prev.pressed.connect(func():
			_preview_state[entry["key"]] = posmod(_app_index(entry) - 1, values.size())
			_refresh_light.call_deferred())
		next.pressed.connect(func():
			_preview_state[entry["key"]] = posmod(_app_index(entry) + 1, values.size())
			_refresh_light.call_deferred())

	if depth > 0:
		item.add_theme_constant_override("margin_left", APP_DEPENDENT_INSET * depth)
		var tail: TextureRect = item.get_node("%Tail")
		tail.visible = ResourceLoader.exists(APP_TAIL_TEXTURE)
		if tail.visible:
			var atlas := AtlasTexture.new()
			atlas.atlas = load(APP_TAIL_TEXTURE)
			tail.texture = atlas
	return item

# setting_line_item.gd's set_tail_reach, with the space between the rows.
func _app_tail_reach(item: Control, parent_item: Control) -> void:
	var tail: TextureRect = item.get_node("%Tail")
	if not tail.visible or not tail.texture is AtlasTexture:
		return
	var atlas: AtlasTexture = tail.texture
	var space_above := item.position.y - parent_item.position.y - parent_item.size.y
	var row_center := floorf(item.get_node("Content/Hbox").get_combined_minimum_size().y / 2.0)
	var tex_height := float(atlas.atlas.get_height())
	var height := clampf(space_above + row_center, 0.0, tex_height)
	atlas.region = Rect2(0, tex_height - height, atlas.atlas.get_width(), height)
	tail.position = Vector2(APP_TAIL_OFFSET_X, row_center - height)
	tail.size = Vector2(atlas.atlas.get_width(), height)

# Removes the preview copy's scripts and the scene connections to them, which
# would error in the editor (they aren't tool scripts).
func _strip_scripts(root: Node) -> void:
	var nodes: Array = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for node in nodes:
		for sig in node.get_signal_list():
			for connection in node.get_signal_connection_list(sig["name"]):
				var target = connection["callable"].get_object()
				if target is Node and (target == root or root.is_ancestor_of(target)):
					node.disconnect(sig["name"], connection["callable"])
		node.set_script(null)

func _margin(px: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	return m

# Text under the preview: when it's shown, and how to try it.
func _preview_note(entry: Dictionary) -> String:
	var lines := PackedStringArray()
	var conditions = entry["data"].get("visible_when")
	if conditions is Dictionary and not conditions.is_empty():
		var parts := PackedStringArray()
		for k in conditions:
			var other := model.find(k)
			var other_name: String = str(other["data"].get("display_name", k)) if not other.is_empty() else k
			var wanted: Array = conditions[k] if conditions[k] is Array else []
			var wanted_text := PackedStringArray(wanted.map(func(v): return _option_label(other, v)))
			parts.append("%s is %s" % [other_name, " or ".join(wanted_text) if not wanted_text.is_empty() else "…"])
		lines.append("[i]Only shown when %s.[/i]" % _escape(" and ".join(parts)))
	lines.append("Click the arrows or button to try it; this doesn't change where it starts.")
	return "[color=gray]%s[/color]" % "\n".join(lines)

func _preview_text(entry: Dictionary) -> String:
	var data: Dictionary = entry["data"]
	var name := _escape(str(data.get("display_name", "")).strip_edges())
	if name == "":
		name = "[i]no name[/i]"
	var values: Array = data.get("values", []) if data.get("values") is Array else []
	var labels: Array = data.get("labels", []) if data.get("labels") is Array else []
	var i := Model._index_of(values, data.get("default"))
	var shown := ""
	if entry["kind"] == Model.KIND_TOGGLE:
		var on_text: String = str(labels[0]) if labels.size() > 0 and str(labels[0]).strip_edges() != "" else Model.TOGGLE_ON_TEXT
		var off_text: String = str(labels[1]) if labels.size() > 1 and str(labels[1]).strip_edges() != "" else Model.TOGGLE_OFF_TEXT
		shown = "[ %s ]" % _escape(on_text if _is_true(data.get("default")) else off_text)
	elif i >= 0:
		var label: String = str(labels[i]) if i < labels.size() else Model.display_value(values[i])
		var swatch := ""
		if entry["kind"] == Model.KIND_COLOR and Color.html_is_valid(str(values[i])):
			swatch = "[color=#%s]■[/color] " % str(values[i]).trim_prefix("#")
		shown = "‹ %s%s ›" % [swatch, _escape(label)]
	var text := "[b]%s[/b]      %s" % [name, shown]
	var description := str(data.get("description", "")).strip_edges()
	if description != "":
		text += "\n[color=gray]%s[/color]" % _escape(description)
	var conditions = data.get("visible_when")
	if conditions is Dictionary and not conditions.is_empty():
		var parts := PackedStringArray()
		for k in conditions:
			var other := model.find(k)
			var other_name: String = str(other["data"].get("display_name", k)) if not other.is_empty() else k
			var wanted: Array = conditions[k] if conditions[k] is Array else []
			var wanted_text := PackedStringArray(wanted.map(func(v): return _option_label(other, v)))
			parts.append("%s is %s" % [other_name, " or ".join(wanted_text) if not wanted_text.is_empty() else "…"])
		text += "\n[color=gray][i]Only shown when %s.[/i][/color]" % _escape(" and ".join(parts))
	return text

func _option_label(entry: Dictionary, v) -> String:
	if entry.is_empty():
		return Model.display_value(v)
	var values: Array = entry["data"].get("values", [])
	var labels: Array = entry["data"].get("labels", []) if entry["data"].get("labels") is Array else []
	var i := Model._index_of(values, v)
	if entry["kind"] == Model.KIND_TOGGLE:
		var fallback := Model.TOGGLE_ON_TEXT if _is_true(v) else Model.TOGGLE_OFF_TEXT
		return str(labels[i]) if i >= 0 and i < labels.size() and str(labels[i]) != "" else fallback
	return str(labels[i]) if i >= 0 and i < labels.size() else Model.display_value(v)

func _update_footer() -> void:
	var dirty := model.is_dirty()
	var problems := model.entries.filter(func(e): return not model.issues(e)["errors"].is_empty()).size()
	_revert_button.disabled = not dirty
	_save_button.disabled = not dirty or problems > 0 or model.error != ""
	var color := _editor_color("font_readonly_color", Color(0.7, 0.7, 0.7))
	if model.error != "":
		_status.text = model.error
		color = _editor_color("error_color", Color(1, 0.47, 0.42))
	elif problems > 0:
		_status.text = "%d setting%s need%s fixing before saving (marked with a red icon)." % [problems, "" if problems == 1 else "s", "s" if problems == 1 else ""]
		color = _editor_color("error_color", Color(1, 0.47, 0.42))
	elif _overwrite_armed:
		_status.text = "theme.json's settings were changed outside this window since it loaded them. Save again to replace them with these, or Revert to load theirs."
		color = _editor_color("warning_color", Color(0.88, 0.69, 0.31))
	elif dirty:
		_status.text = "Unsaved changes."
	else:
		_status.text = "%d setting%s. Saved." % [model.entries.size(), "" if model.entries.size() == 1 else "s"]
	_status.add_theme_color_override("font_color", color)

# ---- Saving and closing ----

# Text fields commit renames (and the option values other settings' conditions
# point at) when they lose focus; this makes sure that has happened.
func _commit_pending_edits() -> void:
	var focused := gui_get_focus_owner()
	if focused:
		focused.release_focus()
	var entry = _selected_entry()
	if entry:
		_commit_key(entry)

func _commit_key(entry: Dictionary) -> void:
	var before: String = entry["committed_key"]
	model.commit_key(entry)
	if before != entry["committed_key"]:
		_rebuild_list()
	_refresh_light()

func _on_save() -> void:
	_commit_pending_edits()
	if model.has_errors() or model.error != "":
		_update_footer()
		return
	var current := FileAccess.get_file_as_string(json_path)
	var changed_outside := ThemeJson.object_entries(current, "settings") != ThemeJson.object_entries(_loaded_text, "settings")
	if changed_outside and not _overwrite_armed:
		_overwrite_armed = true
		_update_footer()
		return
	var new_text := model.apply_to_text(current)
	if ThemeJson.parse(new_text).is_empty():
		_status.text = "Saving would have produced a theme.json that doesn't parse, so nothing was written. (This is a bug in the settings editor.)"
		return
	var err: Error = write_json.call(json_path, current, new_text)
	if err != OK:
		_status.text = "Couldn't write theme.json (%s)." % error_string(err)
		return
	_reload(_selected_key())
	saved.emit()

func _on_close_requested() -> void:
	_commit_pending_edits()
	if model.is_dirty():
		_discard_dialog.popup_centered()
	else:
		hide()

# ---- Small UI helpers ----

func _section_title(text: String) -> Control:
	var box := VBoxContainer.new()
	box.add_child(HSeparator.new())
	var label := Label.new()
	label.text = text
	var bold := _editor_font("bold")
	if bold:
		label.add_theme_font_override("font", bold)
	box.add_child(label)
	return box

func _hint(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 200
	label.add_theme_color_override("font_color", _editor_color("font_readonly_color", Color(0.65, 0.65, 0.65)))
	return label

func _error_label(text: String) -> Label:
	var label := _hint(text)
	label.add_theme_color_override("font_color", _editor_color("error_color", Color(1, 0.47, 0.42)))
	return label

func _small_label(text: String, min_width: int) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = min_width
	label.add_theme_color_override("font_color", _editor_color("font_readonly_color", Color(0.65, 0.65, 0.65)))
	return label

func _rich() -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.selection_enabled = true
	rich.scroll_active = false
	return rich

func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	return grid

func _grid_row(grid: GridContainer, label_text: String, control: Control, tooltip := "") -> void:
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 100
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tooltip != "":
		control.tooltip_text = tooltip
	grid.add_child(control)

func _icon_button(icon_name: String, tooltip: String, callback: Callable) -> Button:
	var button := Button.new()
	button.icon = _icon(icon_name)
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	return button

func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer

# Values to tick when a condition on another setting is added: its default.
func _starting_values(other: Dictionary) -> Array:
	var default = other["data"].get("default")
	return [] if default == null else [default]

func _is_true(v) -> bool:
	return v is bool and v

func _escape(text: String) -> String:
	return text.replace("[", "[lb]")

func _editor_theme() -> Theme:
	return EditorInterface.get_editor_theme() if Engine.is_editor_hint() else null

func _icon(icon_name: String) -> Texture2D:
	var t := _editor_theme()
	return t.get_icon(icon_name, "EditorIcons") if t and t.has_icon(icon_name, "EditorIcons") else null

func _editor_color(color_name: String, fallback: Color) -> Color:
	var t := _editor_theme()
	return t.get_color(color_name, "Editor") if t and t.has_color(color_name, "Editor") else fallback

func _editor_font(font_name: String) -> Font:
	var t := _editor_theme()
	return t.get_font(font_name, "EditorFonts") if t and t.has_font(font_name, "EditorFonts") else null

func _editor_stylebox(style_name: String, type_name: String) -> StyleBox:
	var t := _editor_theme()
	return t.get_stylebox(style_name, type_name) if t and t.has_stylebox(style_name, type_name) else null
