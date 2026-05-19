extends PanelContainer

func _ready() -> void:
	_update_element()
	ThemeManager.theme_settings_updated.connect(_update_element)

func _update_element():
	pass
	#print(ThemeManager.theme_path)
	#var color = ThemeManager.settings["songo_background_color"]
	#var style = get_theme_stylebox("panel").duplicate()
	#add_theme_stylebox_override("panel", style)
	#style.bg_color = color
