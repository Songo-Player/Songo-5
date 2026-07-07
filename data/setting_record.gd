class_name SettingRecord extends Resource

@export var name: String = "Unknown Setting"
@export var icon: Texture2D
@export var controller_method: String

func _init(name_arg, controller_method_arg, is_info):
	name = name_arg
	controller_method = controller_method_arg
	if is_info:
		icon = load("res://assets/info.svg")
	else:
		icon = load("res://assets/gear.svg")
	
