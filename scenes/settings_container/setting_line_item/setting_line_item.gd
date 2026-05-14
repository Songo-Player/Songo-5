extends VBoxContainer
class_name SettingLineItem

signal value_updated(value)

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
		$SettingDescription.visible = true
		$SettingDescription.text = setting_info["description"]

	if _is_bool_setting():
		setup_bool_setting()
	elif _is_list_setting():
		setup_list_setting()

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
