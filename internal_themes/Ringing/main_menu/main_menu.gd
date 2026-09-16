@tool
extends MarginContainer

@export var rotation_tween_duration: float = 0.4
@export var rotation_transition: Tween.TransitionType = Tween.TRANS_CUBIC
@export var rotation_ease: Tween.EaseType = Tween.EASE_OUT

@onready var menu_item_scn = load("res://internal_themes/Ringing/main_menu/main_menu_item.tscn")

const EDITOR_PREVIEW_ITEMS := [
	["All Songs", "res://assets/music.svg"],
	["Albums", "res://assets/record.svg"],
	["Artists", "res://assets/user.svg"],
	["Playlists", "res://assets/layergroup.svg"],
	["Settings", "res://assets/gear.svg"],
	["Exit", "res://assets/exit_walk.svg"],
]

var menu_item_inner_rotate = []
var menu_item_placement_rotation = []
var _rotation_tween: Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var menu_items := _resolve_menu_items()
	var total := menu_items.size()
	var buttons: Array[Button] = []
	for i in range(total):
		var menu_item = menu_items[i]
		var item = menu_item_scn.instantiate()

		item.rotation_degrees = (360.0 / total) * i
		%MainMenuContainer.add_child(item)
		item.icon.texture = menu_item.icon()
		buttons.append(item.button)

		var target_rotation := -(360.0 / total) * i
		item.button.focus_entered.connect(_rotate_menu_to.bind(target_rotation))
		if menu_item.action.is_valid():
			item.button.pressed.connect(menu_item.action)

	for i in range(total):
		var left := buttons[(i - 1 + total) % total]
		var right := buttons[(i + 1) % total]
		buttons[i].focus_neighbor_left = buttons[i].get_path_to(left)
		buttons[i].focus_neighbor_right = buttons[i].get_path_to(right)

	if Engine.is_editor_hint():
		return

	%FlameLabel.visible = _resolve_menu_items().size() == 2
	
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

func _process(delta: float) -> void:
	pass

func _rotate_menu_to(degrees: float) -> void:
	var current: float = %MainMenuContainer.rotation_degrees
	# Find the shortest equivalent angle to rotate to, avoiding a full 360 spin
	var delta: float = fposmod(degrees - current + 180.0, 360.0) - 180.0
	var target: float = current + delta

	if _rotation_tween:
		_rotation_tween.kill()
	_rotation_tween = create_tween()
	_rotation_tween.set_trans(rotation_transition)
	_rotation_tween.set_ease(rotation_ease)
	_rotation_tween.tween_property(%MainMenuContainer, "rotation_degrees", target, rotation_tween_duration)
