extends Control
class_name ScaledControl

@export var scale_factor: float = 1.0
var child_target: Control
var original_child_height
var original_child_width
var songo_data = SongoDataResource.get_instance()

func _ready() -> void:
	songo_data.scale_components.append(self)

func _process(delta: float) -> void:
	scale_me()
	
func scale_me():
	child_target = get_child(0)
	original_child_height = child_target.size.y
	original_child_width = child_target.size.x
	
	child_target.scale = Vector2(scale_factor, scale_factor)
	child_target.size.x = size.x
	resize_to_child()


func resize_to_child():
	custom_minimum_size.x = get_parent().size.x
	#custom_minimum_size.x = child_target.size.x
	custom_minimum_size.y = child_target.size.y
