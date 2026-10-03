class_name SettingRecord extends Resource

@export var name: String = "Unknown Setting"
@export var icon: Texture2D
@export var controller_method: String
var is_info: bool
# Set by plugins, whose pages aren't Controller methods. Wins over controller_method.
var action: Callable

func _init(name_arg, controller_method_arg, is_info_arg):
	name = name_arg
	controller_method = controller_method_arg
	is_info = is_info_arg
	if is_info:
		icon = load("res://assets/info.svg")
	else:
		icon = load("res://assets/gear.svg")

func trigger():
	if action.is_valid():
		action.call()
	else:
		Controller.call(controller_method)
