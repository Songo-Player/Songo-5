@tool
extends ScrollContainer

var songo_settings = SongoSettings.get_instance()
var tex_panels = []
var buttons: Array[Button] = []

@onready var large_item_scn = load("res://internal_themes/SongoClassic/main_menu/main_menu_item_large.tscn")
@onready var small_item_scn = load("res://internal_themes/SongoClassic/main_menu/main_menu_item_small.tscn")

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

func _ready():
	var menu_items := _resolve_menu_items()
	var total := menu_items.size()
	# The trailing two items (conventionally Settings/Exit) always render as
	# the compact icon-only tiles in the side column; everything before them
	# renders as a big gradient tile in the main row.
	var primary_count := total - 2
	for i in range(total):
		var menu_item = menu_items[i]
		var is_small := i >= total - 2
		var item

		if is_small:
			item = small_item_scn.instantiate()
			%SideColumn.add_child(item)
			var style := StyleBoxFlat.new()
			style.bg_color = SMALL_STYLE_LAST_COLOR if i == total - 1 else SMALL_STYLE_COLOR
			item.color_panel.add_theme_stylebox_override("panel", style)
		else:
			item = large_item_scn.instantiate()
			%MainRow.add_child(item)
			%MainRow.move_child(%SideColumn, %MainRow.get_child_count() - 1)
			item.gradient_panel.add_theme_stylebox_override("panel", LARGE_STYLES[i % LARGE_STYLES.size()])
			item.label.text = menu_item.label
			tex_panels.append(item.icon)

		item.icon.texture = menu_item.icon()
		if menu_item.action.is_valid():
			item.button.pressed.connect(menu_item.action)
		item.button.mouse_entered.connect(item.button.grab_focus)
		buttons.append(item.button)

	# The joke placeholder only makes sense once you've hidden every primary
	# browsing item and only Settings/Exit are left.
	%FlameContainer.visible = primary_count <= 0

	update_main_menu_size()

	if Engine.is_editor_hint():
		return

	await get_tree().process_frame
	buttons[0].grab_focus()

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

func update_main_menu_size():
	if Engine.is_editor_hint():
		return
	var size = ThemeManager.settings["songo_main_menu_size"]
	if SongoPlayerV2.is_playing() && size == 220:
		size = 172

	for tex_panel in tex_panels:
		tex_panel.custom_minimum_size = Vector2(size, size)

func _on_resized() -> void:
	update_main_menu_size()

func _on_tree_entered() -> void:
	update_main_menu_size()
