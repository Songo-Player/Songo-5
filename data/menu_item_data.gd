class_name MenuItemData
extends RefCounted

var label: String
var icon_path: String
var action: Callable

func _init(p_label: String, p_icon_path: String, p_action: Callable) -> void:
	label = p_label
	icon_path = p_icon_path
	action = p_action

func icon() -> Texture2D:
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null
	return load(icon_path)

func trigger() -> void:
	if action.is_valid():
		action.call()
