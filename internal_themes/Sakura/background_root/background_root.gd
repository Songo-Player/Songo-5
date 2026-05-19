extends AspectRatioContainer


# Called when the node enters the scene tree for the first time.

func _ready() -> void:
	_update_element()
	ThemeManager.theme_settings_updated.connect(_update_element)
	DeviceOS.pseudo_sleep.connect(func(): %VideoStreamPlayer.stop())
	DeviceOS.pseudo_sleep_wake.connect(func(): %VideoStreamPlayer.play())

	
func _update_element():
	var background = ThemeManager.settings["background"]
	var full_path = ThemeManager.theme_path + "/" + background
	%VideoStreamPlayer.stream = load(full_path)
	%VideoStreamPlayer.paused = false
	%VideoStreamPlayer.play()
	if ThemeManager.settings["static_background"]:
		%VideoStreamPlayer.paused = true
		
	var mat := $VideoStreamPlayer.material as ShaderMaterial
	mat.set_shader_parameter("mirrored", ThemeManager.settings["x_flip_background"])
	
	var alignment = ThemeManager.settings["background_alignment"]
	
	if alignment == "left": alignment_horizontal = AspectRatioContainer.ALIGNMENT_BEGIN
	if alignment == "center": alignment_horizontal = AspectRatioContainer.ALIGNMENT_CENTER
	if alignment == "right": alignment_horizontal = AspectRatioContainer.ALIGNMENT_END
