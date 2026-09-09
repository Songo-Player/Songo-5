extends MarginContainer

@export var rotation_tween_duration: float = 0.4
@export var rotation_transition: Tween.TransitionType = Tween.TRANS_CUBIC
@export var rotation_ease: Tween.EaseType = Tween.EASE_OUT

@onready var menu_item_scn = load("res://internal_themes/Ringing/main_menu/main_menu_item.tscn")

var menu_item_inner_rotate = []
var menu_item_placement_rotation = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var total := Controller.menu_items.size()
	var buttons: Array[Button] = []
	for i in range(total):
		var menu_item = Controller.menu_items[i]
		var item = menu_item_scn.instantiate()
		
		item.rotation_degrees = (360.0 / total) * i
		%MainMenuContainer.add_child(item)
		item.icon.texture = menu_item.icon()
		buttons.append(item.button)

		var target_rotation := -(360.0 / total) * i
		item.button.focus_entered.connect(_rotate_menu_to.bind(target_rotation))
		item.button.pressed.connect(menu_item.action)

	for i in range(total):
		var left := buttons[(i - 1 + total) % total]
		var right := buttons[(i + 1) % total]
		buttons[i].focus_neighbor_left = buttons[i].get_path_to(left)
		buttons[i].focus_neighbor_right = buttons[i].get_path_to(right)
		
	await get_tree().process_frame
	buttons[0].grab_focus()

func _process(delta: float) -> void:
	pass

var _rotation_tween: Tween

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
