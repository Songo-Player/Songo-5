extends PanelContainer

@onready var songo_settings = SongoSettings.get_instance()

func _ready() -> void:
	_update_element()
	ThemeManager.theme_settings_updated.connect(_update_element)
	Controller.page_changed.connect(_on_page_changed)

func _process(delta: float):
	%ListLevelVisualizerContainer.add_theme_constant_override("margin_left", songo_settings.content_margin-20)
	
func _update_element():
	pass
	#print(ThemeManager.theme_path)
	#var color = ThemeManager.settings["songo_background_color"]
	#var style = get_theme_stylebox("panel").duplicate()
	#add_theme_stylebox_override("panel", style)
	#style.bg_color = color
	
func _on_page_changed():
	var active_container = Controller.active_container
	if active_container is ThemeMainMenu || active_container is ThemeMainSongView:
		%ListLevelVisualizerContainer.hide()
	else:
		%ListLevelVisualizerContainer.show()
