@tool
extends MarginContainer
## The main menu as a picture's opening: a deco title card on the left, and
## the menu as its reels on the right. The focused reel steps into a
## spotlight, gets underlined in the accent, and the title card types out a
## line of dialogue for it.

const P = preload("../assets/palette.gd")
const FONT_TITLE = preload("../assets/font_title.tres")
const FONT_TYPE = preload("../assets/font_type.tres")

const ROW_HEIGHT := 44
const TYPE_SPEED := 0.022  # seconds per character of dialogue
const FADE := 0.18
# How long after the menu opens a focused reel still types its line out.
const TYPE_WINDOW_MS := 600

const EDITOR_PREVIEW_ITEMS := [
	["All Songs", "res://assets/music.svg"],
	["Albums", "res://assets/record.svg"],
	["Artists", "res://assets/user.svg"],
	["Playlists", "res://assets/layergroup.svg"],
	["Settings", "res://assets/gear.svg"],
	["Exit", "res://assets/exit_walk.svg"],
]

const LINES := {
	"all songs": "Every song in this town has a story. Most of them end badly.",
	"albums": "Records don't lie. People do.",
	"artists": "Round up the usual suspects.",
	"playlists": "Somebody's been keeping a list. Names. Dates.",
	"settings": "Let's go over the details one more time.",
	"exit": "Turn up your collar. It's raining out there.",
}
const FALLBACK_LINE := "Another lead. Could be nothing. Could be everything."

const NUMBER_WORDS := ["NO", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE", "TEN", "ELEVEN", "TWELVE"]

var buttons: Array[Button] = []
var _rows: Array[Dictionary] = []
var _spot_texture: GradientTexture2D
var _type_tween: Tween
var _current_row := {}
# Until this time (in msec), a newly focused reel types its line out.
var _type_until := 0

func _ready() -> void:
	_spot_texture = _make_spotlight()
	var items := _resolve_menu_items()
	for i in items.size():
		_add_row(items[i], i)
	var count := items.size()
	%ReelCount.text = "A PICTURE IN %s REEL%s" % [NUMBER_WORDS[count] if count < NUMBER_WORDS.size() else str(count), "" if count == 1 else "S"]

	for i in buttons.size():
		var up := buttons[(i - 1 + buttons.size()) % buttons.size()]
		var down := buttons[(i + 1) % buttons.size()]
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(up)
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(down)

	if Engine.is_editor_hint():
		if not _rows.is_empty(): _show_focus(_rows[0], true)
		return
	_apply_settings()
	ThemeManager.theme_settings_updated.connect(_apply_settings)
	tree_entered.connect(_on_tree_entered)
	_type_until = Time.get_ticks_msec() + TYPE_WINDOW_MS
	if not buttons.is_empty(): buttons[0].grab_focus()

# Controller isn't available while editing (it's an autoload), so the editor
# gets a fixed set of entries just to preview the layout.
func _resolve_menu_items() -> Array[MenuItemData]:
	if Engine.is_editor_hint():
		var preview: Array[MenuItemData] = []
		for entry in EDITOR_PREVIEW_ITEMS:
			preview.append(MenuItemData.new(entry[0], entry[1], Callable()))
		return preview
	return Controller.menu_items

func _make_spotlight() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.2), Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.35, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 32
	return texture

func _add_row(item: MenuItemData, index: int) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	button.focus_mode = Control.FOCUS_ALL
	var empty := StyleBoxEmpty.new()
	for style in ["normal", "hover", "focus", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(style, empty)
	%Rows.add_child(button)

	var spot := TextureRect.new()
	spot.texture = _spot_texture
	spot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spot.stretch_mode = TextureRect.STRETCH_SCALE
	spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spot.modulate = Color(P.blind_light(), 0.0)
	button.add_child(spot)
	spot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	spot.offset_left = -30
	spot.offset_right = 10
	spot.offset_top = -6
	spot.offset_bottom = 6

	var columns := HBoxContainer.new()
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_theme_constant_override("separation", 12)
	button.add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.offset_left = 4
	columns.offset_right = -8

	var numeral := Label.new()
	numeral.text = P.roman(index + 1) + "."
	numeral.custom_minimum_size = Vector2(40, 0)
	numeral.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	numeral.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	numeral.add_theme_font_override("font", FONT_TYPE)
	numeral.add_theme_font_size_override("font_size", 14)
	numeral.add_theme_color_override("font_color", P.TEXT_DIM)
	columns.add_child(numeral)

	var title := Label.new()
	title.text = item.label.to_upper()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", P.TEXT_DIM)
	columns.add_child(title)

	# The underline sits under the name, from the numeral's edge.
	var underline := ColorRect.new()
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underline.color = P.accent()
	button.add_child(underline)
	underline.position = Vector2(56, ROW_HEIGHT - 8)
	underline.size = Vector2(0, 2)

	var row := {
		"button": button, "spot": spot, "numeral": numeral, "name": title,
		"underline": underline, "index": index,
		"line": LINES.get(item.label.to_lower(), FALLBACK_LINE),
	}
	_rows.append(row)
	buttons.append(button)

	button.focus_entered.connect(_show_focus.bind(row, true))
	button.focus_exited.connect(_show_focus.bind(row, false))
	if item.action.is_valid():
		button.pressed.connect(item.action)

func _show_focus(row: Dictionary, focused: bool) -> void:
	row.name.add_theme_color_override("font_color", P.TEXT_BRIGHT if focused else P.TEXT_DIM)
	row.numeral.add_theme_color_override("font_color", P.accent_ink() if focused else P.TEXT_DIM)
	var reach: float = maxf(row.button.size.x - 70.0, 60.0)
	var name_width: float = row.name.get_theme_font("font").get_string_size(row.name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var target_width := minf(name_width, reach) if focused else 0.0
	if Engine.is_editor_hint():
		row.spot.modulate.a = 1.0 if focused else 0.0
		row.underline.size.x = target_width
		_type_line(row, false)
		return
	var tween: Tween = row.button.create_tween().set_parallel()
	tween.tween_property(row.spot, "modulate:a", 1.0 if focused else 0.0, FADE)
	tween.tween_property(row.underline, "size:x", target_width, FADE * 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if focused: _type_line(row, Time.get_ticks_msec() <= _type_until)

# The menu is kept alive while other pages are open, so each time it comes
# back the line on the card is typed out again. Moving between reels after
# that swaps the line in at once.
func _on_tree_entered() -> void:
	_type_until = Time.get_ticks_msec() + TYPE_WINDOW_MS
	if not _current_row.is_empty(): _type_line(_current_row, true)

# The title card names the reel and shows its line of dialogue, typed out
# or all at once.
func _type_line(row: Dictionary, animate: bool) -> void:
	# Focus landing back on the reel already being typed shouldn't cut it short.
	var typing := _type_tween != null and _type_tween.is_running()
	if not animate and typing and row == _current_row: return
	_current_row = row
	%ReelLabel.text = "REEL %s" % P.roman(row.index + 1)
	%Tagline.text = "\"%s\"" % row.line
	if _type_tween: _type_tween.kill()
	if not animate:
		%Tagline.visible_ratio = 1.0
		return
	%Tagline.visible_ratio = 0.0
	_type_tween = create_tween()
	_type_tween.tween_property(%Tagline, "visible_ratio", 1.0, %Tagline.text.length() * TYPE_SPEED)

func _apply_settings() -> void:
	%ReelLabel.add_theme_color_override("font_color", P.accent_ink())
	for row in _rows:
		row.underline.color = P.accent()
		row.spot.modulate = Color(P.blind_light(), row.spot.modulate.a)
	# The host keeps the menu out of the tree while other pages are open.
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	for row in _rows:
		if row.button == focused:
			row.numeral.add_theme_color_override("font_color", P.accent_ink())
