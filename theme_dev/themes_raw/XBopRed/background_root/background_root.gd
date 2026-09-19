extends PanelContainer

# [type, style_name] pairs for the base Theme's accent-colored styleboxes.
const ACCENT_STYLES := [
	["Button", "focus"],
	["ListButton", "focus"],
	["VScrollBar", "grabber_highlight"],
	["VScrollBar", "grabber_pressed"],
]

func _ready() -> void:
	_update_element()
	ThemeManager.theme_settings_updated.connect(_update_element)

func _update_element():
	var accent = Color(ThemeManager.settings["accent_color"])
	var base_theme := get_tree().root.theme
	for entry in ACCENT_STYLES:
		var style := base_theme.get_stylebox(entry[1], entry[0])
		if style: style.bg_color = accent
