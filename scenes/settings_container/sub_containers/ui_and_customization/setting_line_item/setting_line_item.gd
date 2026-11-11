extends MarginContainer
class_name SettingLineItem

signal value_updated(value)

const TAIL_TEXTURE: Texture2D = preload("res://assets/folder_nested_line_long.png")
const DEPENDENT_INSET := 28
# Puts the tail's line slightly inset from the start of the parent setting's label.
const TAIL_OFFSET_X := 6 - DEPENDENT_INSET

var setting_info
var setting_value
	
var list_setting_index:
	get: return _get_list_setting_index()
	
var display_name:
	get: return _get_display_name()
	
func setup(info, value):
	setting_info = info
	setting_value = value
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%SettingLabel.text = display_name
	if setting_info.has("description"):
		%SettingDescription.visible = true
		%SettingDescription.text = setting_info["description"]

	if _is_bool_setting():
		setup_bool_setting()
	elif _is_list_setting():
		setup_list_setting()

# Insets this setting and shows its tail if it depends on another setting.
func set_dependent_depth(depth: int) -> void:
	add_theme_constant_override("margin_left", DEPENDENT_INSET * depth)
	%Tail.visible = depth > 0
	if depth > 0:
		var tail_texture := AtlasTexture.new()
		tail_texture.atlas = TAIL_TEXTURE
		%Tail.texture = tail_texture

# Draws the tail from this setting's label row up through the space above it.
# Only the end of the texture with the elbow is used, cropped to fit that space.
func set_tail_reach(space_above: float) -> void:
	var row_center: float = floorf($Content/Hbox.get_combined_minimum_size().y / 2.0)
	var height: float = clampf(space_above + row_center, 0.0, TAIL_TEXTURE.get_height())
	%Tail.texture.region = Rect2(0, TAIL_TEXTURE.get_height() - height, TAIL_TEXTURE.get_width(), height)
	%Tail.position = Vector2(TAIL_OFFSET_X, row_center - height)
	%Tail.size = Vector2(TAIL_TEXTURE.get_width(), height)

func setup_bool_setting():
	%BoolSwapButton.show()
	if setting_info.has("labels"):
		%SettingValueTrueLabel.text = setting_info["labels"][0]
		%SettingValueFalseLabel.text = setting_info["labels"][1]
	_update_bool_setting_ui()

func setup_list_setting():
	%PrevNextContainer.show()
	if setting_info.has("labels"):
		%SettingValueLabel.show()
		%SettingValueLabel.text = setting_info["labels"][list_setting_index]

func _get_list_setting_index():
	return setting_info["values"].find(setting_value)
	
func _get_display_name():
	if setting_info.has("display_name"):
		return setting_info["display_name"]
	else:
		return "Setting"

func _is_bool_setting() -> bool:
	if not setting_info.has("values"): return false
	var arr = setting_info["values"]
	return arr.size() == 2 and true in arr and false in arr
	
func _is_list_setting() -> bool:
	return setting_info.has("values") && setting_info["values"].size() > 1

func _on_prev_value_button_pressed() -> void:
	var new_index = list_setting_index-1
	if new_index < 0: new_index = setting_info["values"].size()-1
	_update_list_setting(new_index)

func _on_next_value_button_pressed() -> void:
	var new_index = list_setting_index+1
	if new_index >= setting_info["values"].size(): new_index = 0
	_update_list_setting(new_index)
	
func _update_list_setting(new_index):
	var new_value = setting_info["values"][new_index]
	value_updated.emit(new_value)
	setting_value = new_value
	%SettingValueLabel.text = setting_info["labels"][list_setting_index]

func _update_bool_setting_ui():
	if setting_info.has("button_text"):
		if setting_info["button_text"] is Array:
			if setting_value: %BoolSwapButton.text = setting_info["button_text"][0]
			else: %BoolSwapButton.text = setting_info["button_text"][1]
		else: 
			%BoolSwapButton.text = setting_info["button_text"]

	if setting_value:
		%SettingValueTrueLabel.show()
		%SettingValueFalseLabel.hide()
	else: 
		%SettingValueFalseLabel.show()
		%SettingValueTrueLabel.hide()

func _on_bool_swap_button_pressed() -> void:
	var new_value = not setting_value
	value_updated.emit(new_value)
	setting_value = new_value
	_update_bool_setting_ui()
