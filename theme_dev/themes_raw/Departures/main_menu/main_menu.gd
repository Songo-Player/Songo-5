@tool
extends MarginContainer
## The main menu as a departures board. Each menu entry is a service leaving
## from this platform: a departure time counted on from the real clock, its
## destination in split flaps, a platform number, and remarks. The focused
## service's remarks flip over to BOARDING.

const P = preload("../assets/palette.gd")
const FlapText = preload("../assets/flap_text.gd")
const FONT = preload("../assets/font_regular.tres")
const FONT_BOLD = preload("../assets/font_bold.tres")

const ROW_HEIGHT := 40
const DEST_CELLS := 13
const REMARK_CELLS := 9
const MINUTES_APART := 7
const ROW_FLIP_DELAY := 0.12

const EDITOR_PREVIEW_ITEMS := [
	["All Songs", "res://assets/music.svg"],
	["Albums", "res://assets/record.svg"],
	["Artists", "res://assets/user.svg"],
	["Playlists", "res://assets/layergroup.svg"],
	["Settings", "res://assets/gear.svg"],
	["Exit", "res://assets/exit_walk.svg"],
]

var buttons: Array[Button] = []
var _rows: Array[Dictionary] = []
var _focus_style: StyleBoxFlat
var _normal_style: StyleBoxFlat
var _blink: Tween
var _clock_24_hour := true

func _ready() -> void:
	_focus_style = _row_style(true)
	_normal_style = _row_style(false)
	%StationFlap.set_text(P.STATION_NAME)
	_clock_24_hour = P.clock_24_hour()

	var items := _resolve_menu_items()
	var now := Time.get_datetime_dict_from_system()
	var first: int = now.hour * 60 + now.minute
	first += 5 - first % 5  # the next five-minute mark, like a real timetable
	for i in items.size():
		_add_row(items[i], i, first + i * MINUTES_APART)
	%ServiceCount.text = "%d SERVICES" % items.size()

	for i in buttons.size():
		var up := buttons[(i - 1 + buttons.size()) % buttons.size()]
		var down := buttons[(i + 1) % buttons.size()]
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(up)
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(down)

	if Engine.is_editor_hint():
		if not _rows.is_empty(): _show_focus(_rows[0], true)
		return
	if not buttons.is_empty(): buttons[0].grab_focus()
	_apply_settings()
	ThemeManager.theme_settings_updated.connect(_apply_settings)
	tree_entered.connect(_refresh_clock_format)

# Controller isn't available while editing (it's an autoload), so the editor
# gets a fixed set of entries just to preview the layout.
func _resolve_menu_items() -> Array[MenuItemData]:
	if Engine.is_editor_hint():
		var preview: Array[MenuItemData] = []
		for entry in EDITOR_PREVIEW_ITEMS:
			preview.append(MenuItemData.new(entry[0], entry[1], Callable()))
		return preview
	return Controller.menu_items

func _add_row(item: MenuItemData, index: int, minutes: int) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal", _normal_style)
	button.add_theme_stylebox_override("hover", _normal_style)
	button.add_theme_stylebox_override("focus", _focus_style)
	button.add_theme_stylebox_override("pressed", _focus_style)
	%Rows.add_child(button)

	var columns := HBoxContainer.new()
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_theme_constant_override("separation", 10)
	button.add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.offset_left = 8
	columns.offset_right = -8

	var time := _flap(5, Vector2(13, 22), 16, FONT_BOLD, "plain")
	columns.add_child(time)

	var icon := TextureRect.new()
	icon.texture = item.icon()
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = P.text_dim()
	columns.add_child(icon)

	var destination := _flap(DEST_CELLS, Vector2(16, 26), 19, FONT_BOLD, "plain")
	destination.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(destination)

	var platform := Label.new()
	platform.text = "%02d" % (index + 1)
	platform.custom_minimum_size = Vector2(30, 0)
	platform.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	platform.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	platform.add_theme_font_size_override("font_size", 14)
	platform.theme_type_variation = &"DepartureDim"
	columns.add_child(platform)

	var remarks := _flap(REMARK_CELLS, Vector2(12, 20), 14, FONT_BOLD, "on_time")
	columns.add_child(remarks)

	var is_exit := item.icon_path.get_file().begins_with("exit")
	var row := {
		"button": button, "time": time, "icon": icon, "destination": destination,
		"remarks": remarks, "idle": "LAST CALL" if is_exit else "ON TIME",
		"active": "FAREWELL" if is_exit else "BOARDING", "minutes": minutes,
	}
	_rows.append(row)
	buttons.append(button)

	# The board fills in row by row when the menu opens.
	var delay := index * ROW_FLIP_DELAY
	time.set_text(_departure_time(minutes), true, delay)
	destination.set_text(item.label, true, delay + 0.05)
	remarks.set_text(row.idle, true, delay + 0.1)

	button.focus_entered.connect(_show_focus.bind(row, true))
	button.focus_exited.connect(_show_focus.bind(row, false))
	if item.action.is_valid():
		button.pressed.connect(item.action)

func _flap(cell_count: int, cell_size: Vector2, font_size: int, font: Font, role: String) -> Control:
	var flap = FlapText.new()
	flap.font = font
	flap.font_size = font_size
	flap.cell_size = cell_size
	flap.cells = cell_count
	flap.role = role
	flap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return flap

func _row_style(focused: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if focused:
		style.bg_color = P.row_focus()
		style.border_width_left = 4
		style.border_color = P.accent_fill()
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_right = 3
	else:
		style.bg_color = Color(0, 0, 0, 0)
		style.border_width_bottom = 1
		style.border_color = P.rule()
	return style

func _show_focus(row: Dictionary, focused: bool) -> void:
	row.destination.role = "accent" if focused else "plain"
	row.icon.modulate = P.accent_ink() if focused else P.text_dim()
	row.remarks.role = "accent" if focused else ("alert" if row.idle == "LAST CALL" else "on_time")
	row.time.refresh()
	row.remarks.set_text(row.active if focused else row.idle)
	row.remarks.modulate.a = 1.0
	if not focused or Engine.is_editor_hint(): return
	if _blink: _blink.kill()
	_blink = create_tween().set_loops()
	_blink.tween_interval(0.6)
	_blink.tween_property(row.remarks, "modulate:a", 0.25, 0.35)
	_blink.tween_property(row.remarks, "modulate:a", 1.0, 0.35)

func _apply_settings() -> void:
	_focus_style.border_color = P.accent_fill()
	_focus_style.bg_color = P.row_focus()
	_normal_style.border_color = P.rule()
	%StationFlap.refresh()
	var frame := $Board.get_theme_stylebox("panel") as StyleBoxFlat
	frame.bg_color = Color(P.panel(), 0.92)
	frame.border_color = P.rule()
	frame.shadow_color = Color(0, 0, 0, 0.15 if P.light() else 0.5)
	$Board/Layout/Rule.color = P.rule()
	# The host keeps the menu out of the tree while other pages are open.
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	for row in _rows:
		_show_focus(row, row.button == focused)

func _departure_time(minutes: int) -> String:
	return P.clock_text((minutes / 60) % 24, minutes % 60)

# The menu stays alive while other pages are open, so the departure times
# catch up here if the app's 24 hour clock setting changed in the meantime.
func _refresh_clock_format() -> void:
	if P.clock_24_hour() == _clock_24_hour: return
	_clock_24_hour = P.clock_24_hour()
	for row in _rows:
		row.time.set_text(_departure_time(row.minutes))
