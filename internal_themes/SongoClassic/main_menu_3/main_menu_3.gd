@tool
extends ScrollContainer

var tiles: Array[Control] = []
var small_items: Array[Control] = []
var buttons: Array[Button] = []

@onready var large_item_scn = load("res://internal_themes/SongoClassic/main_menu/main_menu_item_large.tscn")
@onready var small_item_scn = load("res://internal_themes/SongoClassic/main_menu_3/main_menu_item_small.tscn")

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

const DEFAULT_GAP := 16
const MIN_ICON_SIZE := 24.0
const MIN_SMALL_ICON_SIZE := 16.0
const MIN_LABEL_FONT_SIZE := 12
const MAX_LABEL_FONT_SIZE := 26

func _ready():
	var menu_items := _resolve_menu_items()
	var total := menu_items.size()
	# The trailing two items (conventionally Settings/Exit) always render as
	# the compact icon-only tiles in the side column; everything before them
	# renders as a big gradient tile in the main row.
	var primary_count := total - 2
	for i in range(total):
		var menu_item = menu_items[i]
		var item

		if i >= primary_count:
			item = small_item_scn.instantiate()
			%SideColumn.add_child(item)
			var style := StyleBoxFlat.new()
			style.bg_color = SMALL_STYLE_LAST_COLOR if i == total - 1 else SMALL_STYLE_COLOR
			item.color_panel.add_theme_stylebox_override("panel", style)
			small_items.append(item)
		else:
			item = large_item_scn.instantiate()
			%MainRow.add_child(item)
			%MainRow.move_child(%SideColumn, %MainRow.get_child_count() - 1)
			item.gradient_panel.add_theme_stylebox_override("panel", LARGE_STYLES[i % LARGE_STYLES.size()])
			item.label.text = menu_item.label
			# Keeps a long label from widening its tile past what the fit allowed for.
			item.label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			tiles.append(item)

		# Sized directly by the fit below rather than from the space they're given or
		# their texture's shape, so every tile's size is known up front.
		item.icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		item.icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item.icon.texture = menu_item.icon()
		if menu_item.action.is_valid():
			item.button.pressed.connect(menu_item.action)
		item.button.mouse_entered.connect(item.button.grab_focus)
		item.button.focus_entered.connect(_on_item_focused.bind(menu_item.label))
		buttons.append(item.button)

	# The joke placeholder only makes sense once you've hidden every primary
	# browsing item and only Settings/Exit are left.
	%FlameContainer.visible = primary_count <= 0

	update_main_menu_size()

	if Engine.is_editor_hint():
		return

	# After every layout pass, as those are what scrolling and refits come through.
	sort_children.connect(_center_focus_label)
	%Content.sort_children.connect(_center_focus_label)
	%FocusLabel.resized.connect(_center_focus_label)

	await get_tree().process_frame
	buttons[0].grab_focus()

func _on_item_focused(label: String) -> void:
	%FocusLabel.text = label
	_center_focus_label()

# The label is inside the content that scrolls, so it's held over the middle of the
# view rather than the middle of the row. Setting its position pins its size, so
# that has to be reset for a shorter name to take effect.
func _center_focus_label() -> void:
	%FocusLabel.reset_size()
	%FocusLabel.global_position.x = get_global_rect().get_center().x - %FocusLabel.size.x / 2.0

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

# Sizes everything to the largest that fits the available area. The scroll
# container doesn't pass its contents' size up to its parent, so this can't feed
# back into the size it's measured from.
func update_main_menu_size():
	if not is_node_ready():
		return
	_apply_gap()
	_apply_label_style()
	follow_focus = _fits_height()
	# The content is centered, so leaving this much height spare splits it top and bottom.
	var available: Vector2 = size - Vector2(0, _y_margin() * 2)

	if tiles.is_empty():
		_set_small_icon_size(%FlameContainer.get_combined_minimum_size().y)
		return

	# Fit with full size labels to find how small they need to be, then again with
	# that size, since a shorter label leaves the icon more of the height.
	_set_label_font_size(MAX_LABEL_FONT_SIZE)
	_set_label_font_size(_label_font_size_for(_fit_icon_size(available)))
	var icon_size := _fit_icon_size(available)

	for tile in tiles:
		tile.icon.custom_minimum_size = Vector2(icon_size, icon_size)
	_set_small_icon_size(icon_size + _chrome(tiles[0], tiles[0].icon).y)
	_keep_focus_in_view()

# The largest icon that keeps the row within both limits. The side column's two
# square tiles share the height of a large tile, so each adds half an icon's width
# for the one added to the large tiles.
func _fit_icon_size(available: Vector2) -> float:
	var tile_chrome := _chrome(tiles[0], tiles[0].icon)
	var small_chrome := _chrome(small_items[0], small_items[0].icon) if not small_items.is_empty() else Vector2.ZERO
	var count := tiles.size()

	var row_width: float = available.x - small_chrome.x - count * (tile_chrome.x + %MainRow.get_theme_constant("separation"))
	var column_chrome: float = (tile_chrome.y - %SideColumn.get_theme_constant("separation")) / 2.0 - small_chrome.y
	var fit_width: float = (row_width - column_chrome) / (count + 0.5)
	# Once the side column's icons bottom out it stops shrinking with the tiles.
	if fit_width / 2.0 + column_chrome < MIN_SMALL_ICON_SIZE:
		fit_width = (row_width - MIN_SMALL_ICON_SIZE) / count

	var fit_height: float = available.y - tile_chrome.y
	if %FocusLabelSlot.visible:
		fit_height -= %FocusLabelSlot.custom_minimum_size.y + %Content.get_theme_constant("separation")

	if _fits_height():
		# The row scrolls to make up the width, but a tile needs to fit on screen whole.
		return floorf(max(min(fit_height, available.x - tile_chrome.x), MIN_ICON_SIZE))

	return floorf(max(min(fit_width, fit_height), MIN_ICON_SIZE))

# A tile's size without its icon.
func _chrome(item: Control, icon: Control) -> Vector2:
	return item.get_combined_minimum_size() - icon.custom_minimum_size

# Splits a column of the given height between the side column's tiles.
func _set_small_icon_size(column_height: float) -> void:
	if small_items.is_empty():
		return
	var gaps: int = %SideColumn.get_theme_constant("separation") * (small_items.size() - 1)
	var height_each: float = (column_height - gaps) / small_items.size()
	var icon_size: float = floorf(max(height_each - _chrome(small_items[0], small_items[0].icon).y, MIN_SMALL_ICON_SIZE))
	for item in small_items:
		item.icon.custom_minimum_size = Vector2(icon_size, icon_size)

# The size at which the widest label fits under an icon of the given size.
func _label_font_size_for(icon_size: float) -> int:
	var widest := 0.0
	for tile in tiles:
		var font: Font = tile.label.get_theme_font("font")
		widest = max(widest, font.get_string_size(tile.label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, MAX_LABEL_FONT_SIZE).x)
	if widest <= icon_size:
		return MAX_LABEL_FONT_SIZE
	return max(floori(MAX_LABEL_FONT_SIZE * icon_size / widest), MIN_LABEL_FONT_SIZE)

func _set_label_font_size(font_size: int) -> void:
	for tile in tiles:
		tile.label.add_theme_font_size_override("font_size", font_size)

func _fits_height() -> bool:
	if Engine.is_editor_hint():
		return false
	return ThemeManager.settings.get("main_menu_fit", "width") == "height"

# A refit moves everything, so focus can end up off screen without having changed.
func _keep_focus_in_view() -> void:
	if not follow_focus or not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused and is_ancestor_of(focused):
		ensure_control_visible(focused)

func _y_margin() -> int:
	if Engine.is_editor_hint():
		return 0
	return ThemeManager.settings.get("main_menu_y_margin", 0)

func _apply_gap() -> void:
	if Engine.is_editor_hint():
		return
	var gap: int = ThemeManager.settings.get("main_menu_gap", DEFAULT_GAP)
	# Overriding on every fit, even with the same value, leaves the scroll range stale.
	if %MainRow.get_theme_constant("separation") == gap:
		return
	%Content.add_theme_constant_override("separation", gap)
	%MainRow.add_theme_constant_override("separation", gap)
	%SideColumn.add_theme_constant_override("separation", gap)

func _apply_label_style() -> void:
	if Engine.is_editor_hint():
		return
	var show_labels: bool = ThemeManager.settings.get("main_menu_label_style", "inline") != "on_focus"
	for tile in tiles:
		tile.label.visible = show_labels
	%FocusLabelSlot.visible = not show_labels
	# The label is free to run past its slot when it's too long, which only works
	# because the slot takes no size from it, so the slot's height is set here.
	%FocusLabelSlot.custom_minimum_size.y = %FocusLabel.get_combined_minimum_size().y

func _on_resized() -> void:
	update_main_menu_size()

# Settings can change while this page waits in history, without its size changing.
# Deferred because the tiles haven't rejoined the tree yet and can't be measured.
func _on_tree_entered() -> void:
	update_main_menu_size.call_deferred()
