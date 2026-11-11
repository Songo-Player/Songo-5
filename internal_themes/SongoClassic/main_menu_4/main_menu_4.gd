@tool
extends ScrollContainer

var tiles: Array[Control] = []
var buttons: Array[Button] = []

@onready var item_scn = load("res://internal_themes/SongoClassic/main_menu/main_menu_item_large.tscn")

const PRIMARY_STYLES := [
	preload("../assets/all_songs_gradient_v2.tres"),
	preload("../assets/albums_gradient.tres"),
	preload("../assets/artists_gradient.tres"),
	preload("../assets/playlists_gradient.tres"),
]

const TRAILING_STYLE_COLOR := Color(0.286155, 0.272626, 0.260969, 1)
const TRAILING_STYLE_LAST_COLOR := Color(0.478859, 0.0503185, 0.0318629, 1)

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
const MIN_LABEL_FONT_SIZE := 12
const MAX_LABEL_FONT_SIZE := 26

func _ready():
	var menu_items := _resolve_menu_items()
	var total := menu_items.size()
	# The trailing two items (conventionally Settings/Exit) keep their plain colors
	# rather than a gradient, which also sets them apart at the end of the layout.
	var primary_count := total - 2
	# The joke placeholder takes over the top row once you've hidden every primary
	# browsing item and only Settings/Exit are left.
	%FlameContainer.visible = primary_count <= 0
	var top_row_count := 0 if primary_count <= 0 else ceili(total / 2.0)

	for i in range(total):
		var menu_item = menu_items[i]
		var item = item_scn.instantiate()
		(%TopRow if i < top_row_count else %BottomRow).add_child(item)

		if i < primary_count:
			item.gradient_panel.add_theme_stylebox_override("panel", PRIMARY_STYLES[i % PRIMARY_STYLES.size()])
		else:
			var style := StyleBoxFlat.new()
			style.bg_color = TRAILING_STYLE_LAST_COLOR if i == total - 1 else TRAILING_STYLE_COLOR
			item.gradient_panel.add_theme_stylebox_override("panel", style)

		item.label.text = menu_item.label
		# Keeps a long label from widening its tile past what the fit allowed for.
		item.label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		# Sized directly by the fit below rather than from the space they're given or
		# their texture's shape, so every tile's size is known up front.
		item.icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		item.icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item.icon.texture = menu_item.icon()
		if menu_item.action.is_valid():
			item.button.pressed.connect(menu_item.action)
		item.button.mouse_entered.connect(item.button.grab_focus)
		item.button.focus_entered.connect(_on_item_focused.bind(menu_item.label))
		tiles.append(item)
		buttons.append(item.button)

	update_main_menu_size()

	if Engine.is_editor_hint():
		return

	await get_tree().process_frame
	buttons[0].grab_focus()

func _on_item_focused(label: String) -> void:
	%FocusLabel.text = label

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

# Sizes every tile to the largest that fits the available area. The scroll
# container doesn't pass its contents' size up to its parent, so this can't feed
# back into the size it's measured from.
func update_main_menu_size():
	if not is_node_ready() or tiles.is_empty():
		return
	_apply_gap()
	_apply_label_style()
	# The content is centered, so leaving this much height spare splits it top and bottom.
	var available: Vector2 = size - Vector2(0, _y_margin() * 2)

	# Fit with full size labels to find how small they need to be, then again with
	# that size, since a shorter label leaves the icon more of the height.
	_set_label_font_size(MAX_LABEL_FONT_SIZE)
	_set_label_font_size(_label_font_size_for(_fit_icon_size(available)))
	var icon_size := _fit_icon_size(available)

	for tile in tiles:
		tile.icon.custom_minimum_size = Vector2(icon_size, icon_size)

# The largest icon that keeps the widest row and both rows' height within limits.
func _fit_icon_size(available: Vector2) -> float:
	var chrome: Vector2 = tiles[0].get_combined_minimum_size() - tiles[0].icon.custom_minimum_size
	var row_gap: int = %TopRow.get_theme_constant("separation")
	var column_gap: int = %Rows.get_theme_constant("separation")
	var has_flame: bool = %FlameContainer.visible

	var columns := tiles.size() if has_flame else ceili(tiles.size() / 2.0)
	var height: float = available.y
	var rows := 2
	if has_flame:
		# The placeholder's top row isn't made of tiles, so it comes off the top.
		height -= %FlameContainer.get_combined_minimum_size().y + column_gap
		rows = 1

	var width: float = available.x
	if %FocusLabelColumn.visible:
		width -= %FocusLabelColumn.custom_minimum_size.x + %Content.get_theme_constant("separation")

	var fit_width: float = (width - row_gap * (columns - 1)) / columns - chrome.x
	var fit_height: float = (height - column_gap * (rows - 1)) / rows - chrome.y
	return floorf(max(min(fit_width, fit_height), MIN_ICON_SIZE))

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

func _y_margin() -> int:
	if Engine.is_editor_hint():
		return 0
	return ThemeManager.settings.get("main_menu_y_margin", 0)

func _apply_gap() -> void:
	if Engine.is_editor_hint():
		return
	var gap: int = ThemeManager.settings.get("main_menu_gap", DEFAULT_GAP)
	# Overriding on every fit, even with the same value, leaves the scroll range stale.
	if %Rows.get_theme_constant("separation") == gap:
		return
	%Content.add_theme_constant_override("separation", gap)
	%Rows.add_theme_constant_override("separation", gap)
	%TopRow.add_theme_constant_override("separation", gap)
	%BottomRow.add_theme_constant_override("separation", gap)

func _apply_label_style() -> void:
	if Engine.is_editor_hint():
		return
	var show_labels: bool = ThemeManager.settings.get("main_menu_label_style", "inline") != "on_focus"
	for tile in tiles:
		tile.label.visible = show_labels
	%FocusLabelColumn.visible = not show_labels
	# The label is free to run past its slot when it's too long, which only works
	# because the slot takes no size from it, so the column's width is set here.
	%FocusLabelColumn.custom_minimum_size.x = %FocusLabel.get_combined_minimum_size().y

func _on_resized() -> void:
	update_main_menu_size()

# Settings can change while this page waits in history, without its size changing.
# Deferred because the tiles haven't rejoined the tree yet and can't be measured.
func _on_tree_entered() -> void:
	update_main_menu_size.call_deferred()
