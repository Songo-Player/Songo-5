@tool
extends MarginContainer

@export var scroll_tween_duration: float = 0.4
@export var scroll_transition: Tween.TransitionType = Tween.TRANS_CUBIC
@export var scroll_ease: Tween.EaseType = Tween.EASE_OUT
## How far below the centered tile a tile sits as it leaves the screen, in pixels.
@export var arc_drop: float = 40.0

var songo_settings = SongoSettings.get_instance()
var buttons: Array[Button] = []
var tiles: Array[Control] = []
var small_buttons: Array[Button] = []

var _primary_items: Array[MenuItemData] = []
var _focused_tile: Control
var _scroll_tween: Tween

@onready var scroller: ScrollContainer = %SmoothScrollContainer
@onready var row: HBoxContainer = %MainMenuItems
@onready var large_item_scn = load("res://internal_themes/SongoClassic/main_menu/main_menu_item_large.tscn")
@onready var small_item_scn = load("res://internal_themes/SongoClassic/main_menu_2/main_menu_item_small.tscn")

const LARGE_STYLES := [
	preload("../assets/all_songs_gradient_v2.tres"),
	preload("../assets/albums_gradient.tres"),
	preload("../assets/artists_gradient.tres"),
	preload("../assets/playlists_gradient.tres"),
]

const SMALL_STYLE_COLOR := Color(0.286155, 0.272626, 0.260969, 1)
const SMALL_STYLE_LAST_COLOR := Color(0.478859, 0.0503185, 0.0318629, 1)

const EDITOR_PREVIEW_ITEMS := [
	["All Songs", "res://assets/music.svg"],
	["Albums", "res://assets/record.svg"],
	["Artists", "res://assets/user.svg"],
	["Playlists", "res://assets/layergroup.svg"],
	["Settings", "res://assets/gear.svg"],
	["Exit", "res://assets/exit_walk.svg"],
]

# How many tiles' width of spare row to keep beyond the screen, split between
# both sides, so a drag never reaches the end of the row between wraps.
const ROW_OVERFILL_TILES := 3

# Keeps part of the neighboring tiles in view on tall, narrow screens, where
# filling the height alone would make the focused tile as wide as the screen.
const MAX_TILE_WIDTH_RATIO := 0.6
const MIN_ICON_SIZE := 48.0

const DEFAULT_GAP := 16

const CYCLE_START_LINE_COLOR := Color(0, 0, 0, 0.6)
const CYCLE_START_LINE_WIDTH := 3.0

const ARROW_ACTIONS: Array[StringName] = [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]

func _ready():
	set_process(false)
	var menu_items := _resolve_menu_items()
	var total := menu_items.size()
	# The trailing two items (conventionally Settings/Exit) always render as
	# the compact icon-only tiles in the bottom row; everything before them
	# renders as a big gradient tile in the main row.
	var primary_count := total - 2
	for i in range(total):
		var menu_item = menu_items[i]
		if i < primary_count:
			_primary_items.append(menu_item)
			buttons.append(_add_tile(i).button)
			continue

		var item = small_item_scn.instantiate()
		%SubMenuItems.add_child(item)
		var style := StyleBoxFlat.new()
		style.bg_color = SMALL_STYLE_LAST_COLOR if i == total - 1 else SMALL_STYLE_COLOR
		item.color_panel.add_theme_stylebox_override("panel", style)
		item.icon.texture = menu_item.icon()
		if menu_item.action.is_valid():
			item.button.pressed.connect(menu_item.action)
		item.button.mouse_entered.connect(item.button.grab_focus)
		item.button.focus_entered.connect(_show_focus_label.bind(menu_item.label))
		small_buttons.append(item.button)
		buttons.append(item.button)

	_link_focus_neighbors()

	# Sorting a container is the point where tiles get their final x for the
	# frame, and it also resets their y, so the arc is applied straight after.
	row.sort_children.connect(_update_arc)
	scroller.sort_children.connect(_update_arc)

	# The joke placeholder only makes sense once you've hidden every primary
	# browsing item and only Settings/Exit are left.
	%FlameContainer.visible = primary_count <= 0

	# The label is free to run past its slot when it's too long, which only works
	# because the slot takes no size from it, so the slot's height is set here.
	%FocusLabelSlot.custom_minimum_size.y = %FocusLabel.get_combined_minimum_size().y

	if Engine.is_editor_hint():
		_refresh_carousel()
		return

	scroller.drag_started.connect(_stop_scroll_tween)

	await _refresh_carousel()
	if not is_inside_tree():
		return
	await get_tree().process_frame
	buttons[0].grab_focus()

func _add_tile(primary_index: int) -> Control:
	var menu_item := _primary_items[primary_index]
	var item = large_item_scn.instantiate()
	row.add_child(item)
	item.gradient_panel.add_theme_stylebox_override("panel", LARGE_STYLES[primary_index % LARGE_STYLES.size()])
	item.label.text = menu_item.label
	item.label.visible = _shows_labels()
	item.icon.texture = menu_item.icon()
	if menu_item.action.is_valid():
		item.button.pressed.connect(menu_item.action)
	item.button.focus_entered.connect(_on_tile_focused.bind(item))
	item.button.mouse_entered.connect(_on_tile_hovered.bind(item.button))
	if primary_index == 0:
		item.draw.connect(_draw_cycle_start_line.bind(item))
	tiles.append(item)
	return item

# Marks where the item cycle starts over, in the gap to the left of its first
# tile. Drawn by the tile, so it follows the tile and takes up no row space.
func _draw_cycle_start_line(tile: Control) -> void:
	var x: float = -row.get_theme_constant("separation") / 2.0
	tile.draw_line(Vector2(x, 0.0), Vector2(x, tile.size.y), CYCLE_START_LINE_COLOR, CYCLE_START_LINE_WIDTH)

# Repeats the whole item cycle until the row is wider than the screen by enough
# to always have tiles waiting off both sides. Each repeat goes in at a cycle
# boundary, so the items stay in order however far the row has rotated.
func _ensure_tile_copies() -> void:
	var cycle_size := _primary_items.size()
	var cycle_width := 0.0
	var widest := 0.0
	for i in range(cycle_size):
		cycle_width += _tile_step(tiles[i])
		widest = max(widest, _tile_step(tiles[i]))

	var copies := ceili((scroller.size.x + widest * ROW_OVERFILL_TILES) / cycle_width)
	while tiles.size() < copies * cycle_size:
		var insert_at := tiles[cycle_size - 1].get_index() + 1
		for i in range(cycle_size):
			row.move_child(_add_tile(i), insert_at + i)
		_link_focus_neighbors()
	update_main_menu_size()

# Tiles slide around and sit off screen, so spatial focus search isn't reliable
# here. Tiles link up in a ring; the bottom row stops at its ends.
func _link_focus_neighbors() -> void:
	_link_row(row.get_children().map(func(tile): return tile.button), true)
	_link_row(small_buttons, false)
	if small_buttons.is_empty():
		return
	for tile in tiles:
		tile.button.focus_neighbor_bottom = tile.button.get_path_to(small_buttons[0])

func _link_row(buttons_in_row: Array, wraps: bool) -> void:
	var count := buttons_in_row.size()
	for i in range(count):
		var left: Button = buttons_in_row[posmod(i - 1, count) if wraps else max(i - 1, 0)]
		var right: Button = buttons_in_row[posmod(i + 1, count) if wraps else min(i + 1, count - 1)]
		buttons_in_row[i].focus_neighbor_left = buttons_in_row[i].get_path_to(left)
		buttons_in_row[i].focus_neighbor_right = buttons_in_row[i].get_path_to(right)

# Controller/menu_items isn't available while editing (it's an autoload, only
# present at runtime), so the editor gets a fixed placeholder set just to
# render a preview of the layout.
func _resolve_menu_items() -> Array[MenuItemData]:
	if Engine.is_editor_hint():
		var preview: Array[MenuItemData] = []
		for entry in EDITOR_PREVIEW_ITEMS:
			preview.append(MenuItemData.new(entry[0], entry[1], Callable()))
		return preview
	return Controller.menu_items

func _show_focus_label(label: String) -> void:
	%FocusLabel.text = label

func _on_tile_focused(tile: Control) -> void:
	_focused_tile = tile
	_show_focus_label(tile.label.text)
	# Coming back up from the bottom row returns to the tile that's centered.
	for small_button in small_buttons:
		small_button.focus_neighbor_top = small_button.get_path_to(tile.button)
	_center_tile(tile, true)

func _on_tile_hovered(button: Button) -> void:
	# Tiles slide under the pointer while the row moves, so only a hover made
	# while the row is still counts. Otherwise focus chases the animation, and a
	# fast drag would restart centering underneath itself.
	if (_scroll_tween and _scroll_tween.is_running()) or scroller.is_scrolling():
		return
	button.grab_focus()

# Swiping clears focus, which leaves the d-pad with nothing to move from, so the
# first arrow press afterward just puts focus back on the row.
func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or get_viewport().gui_get_focus_owner() != null:
		return
	for arrow_action in ARROW_ACTIONS:
		if event.is_action_pressed(arrow_action):
			scroller.stop_momentum()
			_nearest_center_button().grab_focus()
			get_viewport().set_input_as_handled()
			return

func _nearest_center_button() -> Button:
	if tiles.is_empty():
		return buttons[0]

	var screen_center: float = scroller.get_global_rect().get_center().x
	var nearest: Control = tiles[0]
	for tile in tiles:
		if absf(tile.get_global_rect().get_center().x - screen_center) < absf(nearest.get_global_rect().get_center().x - screen_center):
			nearest = tile
	return nearest.button

func _center_tile(tile: Control, animate: bool) -> void:
	_stop_scroll_tween()
	if not animate:
		_scroll_to_tile(0.0, tile)
		return

	var start_offset: float = scroller.scroll_horizontal - _centered_scroll(tile)
	_scroll_tween = create_tween()
	_scroll_tween.set_trans(scroll_transition)
	_scroll_tween.set_ease(scroll_ease)
	_scroll_tween.tween_method(_scroll_to_tile.bind(tile), start_offset, 0.0, scroll_tween_duration)

func _stop_scroll_tween() -> void:
	if _scroll_tween:
		_scroll_tween.kill()

# Tweened as an offset from the tile's center rather than a scroll value, since
# the scroll value shifts whenever a tile wraps to the other end mid-slide.
func _scroll_to_tile(offset: float, tile: Control) -> void:
	scroller.scroll_horizontal = roundi(_wrap_tiles(_centered_scroll(tile) + offset))

func _centered_scroll(tile: Control) -> float:
	var tile_x := 0.0
	for i in range(tile.get_index()):
		tile_x += _tile_step(row.get_child(i))
	return tile_x + tile.get_combined_minimum_size().x / 2.0 - scroller.size.x / 2.0

# Measured from minimum sizes because the row hasn't re-sorted yet right after a
# tile moves, so positions and sizes on the tiles can be a frame out of date.
func _tile_step(tile: Control) -> float:
	return tile.get_combined_minimum_size().x + row.get_theme_constant("separation")

# Keeps the view around the middle of the row by moving tiles that have fallen
# too far behind to the opposite end. Returns the scroll value that keeps every
# tile on screen exactly where it was. Focus stays on the same button throughout,
# so wrapping never re-triggers focus changes or the nav sound.
func _wrap_tiles(scroll: float) -> float:
	var middle: float = (row.get_combined_minimum_size().x - scroller.size.x) / 2.0
	for i in range(row.get_child_count()):
		var first: Control = row.get_child(0)
		var last: Control = row.get_child(-1)
		if scroll - middle > _tile_step(first):
			scroll -= _tile_step(first)
			row.move_child(first, -1)
		elif middle - scroll > _tile_step(last):
			scroll += _tile_step(last)
			row.move_child(last, 0)
		else:
			break
	return scroll

# Drops each tile along a curve based on its distance from the center of the
# screen. Only position feeds into it, so slides, drags and wraps all trace the
# same arc. Tiles sit at the top of the space left for them, leaving room below
# for the drop.
func _update_arc() -> void:
	var half_width: float = scroller.size.x / 2.0
	for tile in tiles:
		var half_tile: float = tile.size.x / 2.0
		var distance: float = absf(row.position.x + tile.position.x + half_tile - half_width)
		var reach: float = clampf(distance / (half_width + half_tile), 0.0, 1.0)
		var top: float = max((row.size.y - tile.size.y - arc_drop) / 2.0, 0.0)
		tile.position.y = roundf(top + arc_drop * reach * reach)

func _process(_delta: float) -> void:
	# Catches drags and flings, which move the scroll value directly.
	scroller.scroll_horizontal = roundi(_wrap_tiles(scroller.scroll_horizontal))

# Fits the tiles to the available space, fills the row for that size, then puts
# the current tile back in the center. Runs across frames because each step needs
# the containers to settle from the one before it.
func _refresh_carousel() -> void:
	if tiles.is_empty() or not is_inside_tree():
		return
	_apply_gap()
	_apply_y_margin()
	for tile in tiles:
		tile.label.visible = _shows_labels()
	%FocusLabelSlot.visible = not _shows_labels()
	await get_tree().process_frame
	if not is_inside_tree():
		return

	update_main_menu_size()

	await get_tree().process_frame
	if not is_inside_tree():
		return

	_ensure_tile_copies()

	await get_tree().process_frame
	if not is_inside_tree():
		return
	_center_tile(_focused_tile if _focused_tile else tiles[0], false)
	if not Engine.is_editor_hint():
		set_process(true)

func _shows_labels() -> bool:
	if Engine.is_editor_hint():
		return true
	return ThemeManager.settings.get("main_menu_label_style", "inline") != "on_focus"

func _apply_y_margin() -> void:
	if Engine.is_editor_hint():
		return
	var margin: int = ThemeManager.settings.get("main_menu_y_margin", 0)
	if get_theme_constant("margin_top") == margin:
		return
	add_theme_constant_override("margin_top", margin)
	add_theme_constant_override("margin_bottom", margin)

func _apply_gap() -> void:
	if Engine.is_editor_hint():
		return
	var gap: int = ThemeManager.settings.get("main_menu_gap", DEFAULT_GAP)
	# The row already sits below its own top margin, so that counts toward the gap.
	var label_gap: int = gap - %ScrollerMargin.get_theme_constant("margin_top")
	# Overriding on every fit, even with the same value, leaves the scroll range stale.
	if %Content.get_theme_constant("separation") != label_gap:
		%Content.add_theme_constant_override("separation", label_gap)
	if row.get_theme_constant("separation") == gap:
		return
	row.add_theme_constant_override("separation", gap)
	%SubMenuItems.add_theme_constant_override("separation", gap)
	# The wrap line is drawn in the gap, so it needs redrawing to stay centered.
	for tile in tiles:
		tile.queue_redraw()

# Sizes each icon so a tile, with its margins, label and lowest point on the arc,
# exactly fills the row's height. The scroll container doesn't pass its contents' height up to its parent,
# so this can't feed back into the size it's measured from.
func update_main_menu_size():
	if tiles.is_empty():
		return
	var icon_size: float = tiles[0].icon.custom_minimum_size.y
	var tile_chrome: Vector2 = tiles[0].get_combined_minimum_size() - Vector2(icon_size, icon_size)
	var fit_height: float = scroller.size.y - tile_chrome.y - arc_drop
	var fit_width: float = scroller.size.x * MAX_TILE_WIDTH_RATIO - tile_chrome.x
	var fitted: float = floorf(max(min(fit_height, fit_width), MIN_ICON_SIZE))

	for tile in tiles:
		tile.icon.custom_minimum_size = Vector2(fitted, fitted)

func _on_resized() -> void:
	_refresh_carousel()

func _on_tree_entered() -> void:
	_refresh_carousel()
