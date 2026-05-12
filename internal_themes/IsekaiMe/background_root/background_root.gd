extends AspectRatioContainer


# Called when the node enters the scene tree for the first time.

func _ready() -> void:
	_update_element()
	ThemeManager.theme_settings_updated.connect(_update_element)

func _update_element():
	var background = ThemeManager.settings["background"]
	var full_path = ThemeManager.theme_path + "/" + background
	%VideoStreamPlayer.stream = load(full_path)
	%VideoStreamPlayer.play()
