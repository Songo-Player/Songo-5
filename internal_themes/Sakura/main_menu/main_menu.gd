@tool
extends MarginContainer

@onready var menu_item_scn = load("res://internal_themes/Sakura/main_menu/main_menu_item.tscn")

const EDITOR_PREVIEW_ITEMS := [
	["All Songs", "res://assets/music.svg"],
	["Albums", "res://assets/record.svg"],
	["Artists", "res://assets/user.svg"],
	["Playlists", "res://assets/layergroup.svg"],
	["Settings", "res://assets/gear.svg"],
	["Exit", "res://assets/exit_walk.svg"],
]

var buttons: Array[Button] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_on_clock_timer_timeout()
	_update_element()

	var menu_items := _resolve_menu_items()
	var total := menu_items.size()
	var top_count := ceili(total / 2.0)
	for i in range(total):
		var menu_item = menu_items[i]
		var item = menu_item_scn.instantiate()
		var row := %TopRow if i < top_count else %BottomRow
		row.add_child(item)
		item.icon.texture = menu_item.icon()
		if menu_item.action.is_valid():
			item.button.pressed.connect(menu_item.action)
		item.button.focus_entered.connect(_on_item_focus_entered.bind(menu_item.label))
		buttons.append(item.button)

	for i in range(total):
		var left := buttons[(i - 1 + total) % total]
		var right := buttons[(i + 1) % total]
		buttons[i].focus_neighbor_left = buttons[i].get_path_to(left)
		buttons[i].focus_neighbor_right = buttons[i].get_path_to(right)

	if Engine.is_editor_hint():
		_on_item_focus_entered(menu_items[0].label)
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

func _on_item_focus_entered(label: String) -> void:
	%CurrentMenuItemLabel.text = label

func _on_clock_timer_timeout() -> void:
	var now = Time.get_datetime_dict_from_system()
	var hour_12 = now.hour % 12
	if hour_12 == 0: hour_12 = 12
	var hour = str(hour_12).pad_zeros(2)
	var minute = str(now.minute).pad_zeros(2)
	var am_pm = "am"
	if now.hour >= 12: am_pm = "pm"

	%HourLabel.text = hour
	%MinuteLabel.text = minute
	%AmPmLabel.text = am_pm

func _update_element():
	if Engine.is_editor_hint():
		return
	var alignment = ThemeManager.settings["content_alignment"]

	if alignment == "left": %AlignmentContainer.alignment = HBoxContainer.ALIGNMENT_BEGIN
	if alignment == "center": %AlignmentContainer.alignment = HBoxContainer.ALIGNMENT_CENTER
	if alignment == "right": %AlignmentContainer.alignment = HBoxContainer.ALIGNMENT_END


func _on_tree_entered() -> void:
	_update_element()
