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
	$SettingDescription.visible = setting_info.has("description")
	
	if _is_list_setting(): setup_list_setting()

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

	
func _is_list_setting() -> bool:
	return setting_info.has("values") && setting_info["values"].size() > 2

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
