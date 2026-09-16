@tool
extends MarginContainer

var songo_settings = SongoSettings.get_instance()
var tween

@onready var menu_item_scn = load("res://internal_themes/XBop/main_menu/main_menu_item.tscn")

const ITEM_ANGLE_STEP_DEG := 12.0

const GLOW_ICONS := {
	"music": preload("../assets/music_glow.png"),
	"record": preload("../assets/record_glow.png"),
	"user": preload("../assets/user_glow.png"),
	"layergroup": preload("../assets/layer_group_glow.png"),
	"gear": preload("../assets/gear_glow.png"),
	"exit_walk": preload("../assets/exit_walk_glow.png"),
}

const EDITOR_PREVIEW_ITEMS := [
	["All Songs", "res://assets/music.svg"],
	["Albums", "res://assets/record.svg"],
	["Artists", "res://assets/user.svg"],
	["Playlists", "res://assets/layergroup.svg"],
	["Settings", "res://assets/gear.svg"],
	["Exit", "res://assets/exit_walk.svg"],
]

var buttons: Array[Button] = []

func _ready():
	var menu_items := _resolve_menu_items()
	var total := menu_items.size()
	var step := deg_to_rad(ITEM_ANGLE_STEP_DEG)
	var first_visual_args := []
	for i in range(total):
		var menu_item = menu_items[i]
		var item = menu_item_scn.instantiate()
		item.rotation = ((total - 1) / 2.0 - i) * step
		%ButtonContainer.add_child(item)

		var icon_tex: Texture2D = menu_item.icon()
		var glow_tex: Texture2D = GLOW_ICONS.get(menu_item.icon_path.get_file().get_basename(), icon_tex)
		if i == 0:
			first_visual_args = [item.rotation, icon_tex, glow_tex]

		item.button.text = menu_item.label
		item.button.focus_entered.connect(_on_item_focus_entered.bind(item.rotation, icon_tex, glow_tex))
		if menu_item.action.is_valid():
			item.button.pressed.connect(menu_item.action)
		buttons.append(item.button)

	for i in range(total):
		var left := buttons[(i - 1 + total) % total]
		var right := buttons[(i + 1) % total]
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(left)
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(right)

	if Engine.is_editor_hint():
		_on_item_focus_entered(first_visual_args[0], first_visual_args[1], first_visual_args[2])
		return

	buttons[0].grab_focus()
	_start_flicker()
	_on_theme_settings_updated()
	ThemeManager.theme_settings_updated.connect(_on_theme_settings_updated)

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

func _on_item_focus_entered(item_rotation: float, icon_tex: Texture2D, glow_tex: Texture2D) -> void:
	%FocusedIndicator.rotation = item_rotation
	%MenuIcon.texture = icon_tex
	%MenuIcon2.texture = glow_tex

func _start_flicker() -> void:
	tween = create_tween().set_loops()
	tween.tween_property(%MenuIcon2, "modulate:a", 0.8, 1.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(%MenuIcon2, "modulate:a", 2.0, 1.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _process(delta):
	pass

func _on_theme_settings_updated():
	var content_scale = ThemeManager.settings["content_scale"]
	%ScaleControl.scale = Vector2(content_scale, content_scale)
	pass
