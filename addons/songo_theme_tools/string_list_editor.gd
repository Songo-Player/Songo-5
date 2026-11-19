@tool
extends VBoxContainer

# A list of strings edited one row at a time: each item is a text box with a
# remove button, and "Add" appends an empty row. Used for theme.json arrays
# (tags, co_authors).

signal changed

var add_text := "Add"
var placeholder := ""

var _rows: VBoxContainer
var _add_button: Button
var _editable := true

func _init(p_add_text := "Add", p_placeholder := "") -> void:
	add_text = p_add_text
	placeholder = p_placeholder
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 2)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	add_child(_rows)
	_add_button = Button.new()
	_add_button.text = add_text
	_add_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_add_button.pressed.connect(_on_add_pressed)
	add_child(_add_button)

func _ready() -> void:
	_add_button.icon = _editor_icon("Add")
	for row in _rows.get_children():
		row.get_child(1).icon = _editor_icon("Remove")

# Values in order, trimmed, with blanks and duplicates dropped.
func get_values() -> PackedStringArray:
	var values := PackedStringArray()
	for row in _rows.get_children():
		if row.is_queued_for_deletion():
			continue
		var value: String = row.get_child(0).text.strip_edges()
		if value != "" and not value in values:
			values.append(value)
	return values

func set_values(values: PackedStringArray) -> void:
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	for value in values:
		_add_row(value)

func set_editable(editable: bool) -> void:
	_editable = editable
	_add_button.disabled = not editable
	for row in _rows.get_children():
		row.get_child(0).editable = editable
		row.get_child(1).disabled = not editable

func _add_row(value: String) -> LineEdit:
	var row := HBoxContainer.new()
	var edit := LineEdit.new()
	edit.text = value
	edit.placeholder_text = placeholder
	edit.editable = _editable
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(_t): changed.emit())
	row.add_child(edit)
	var remove := Button.new()
	remove.flat = true
	remove.tooltip_text = "Remove"
	remove.icon = _editor_icon("Remove")
	remove.disabled = not _editable
	remove.pressed.connect(func():
		_rows.remove_child(row)
		row.queue_free()
		changed.emit())
	row.add_child(remove)
	_rows.add_child(row)
	return edit

func _on_add_pressed() -> void:
	var edit := _add_row("")
	edit.grab_focus()
	changed.emit()

func _editor_icon(icon_name: String) -> Texture2D:
	if not Engine.is_editor_hint():
		return null
	var editor_theme := EditorInterface.get_editor_theme()
	if editor_theme and editor_theme.has_icon(icon_name, "EditorIcons"):
		return editor_theme.get_icon(icon_name, "EditorIcons")
	return null
