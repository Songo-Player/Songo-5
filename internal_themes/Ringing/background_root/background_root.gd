extends PanelContainer

# Loaded by path rather than referenced from the scene, so none of this loads
# until the first list page opens.
const LIST_VISUALIZERS_PATH = "res://internal_themes/Ringing/background_root/list_level_visualizers.tscn"

@onready var songo_settings = SongoSettings.get_instance()

var _list_visualizers: Control

func _ready() -> void:
	set_process(false)
	_update_element()
	ThemeManager.theme_settings_updated.connect(_update_element)
	Controller.page_changed.connect(_on_page_changed)

func _process(_delta: float):
	_update_visualizer_margin()

func _update_visualizer_margin():
	_list_visualizers.add_theme_constant_override("margin_left", songo_settings.content_margin-20)

func _update_element():
	pass
	#print(ThemeManager.theme_path)
	#var color = ThemeManager.settings["songo_background_color"]
	#var style = get_theme_stylebox("panel").duplicate()
	#add_theme_stylebox_override("panel", style)
	#style.bg_color = color

func _on_page_changed():
	var active_container = Controller.active_container
	var is_list_page = not (active_container is ThemeMainMenu || Controller.is_song_view(active_container))

	if _list_visualizers == null:
		if not is_list_page: return
		_list_visualizers = load(LIST_VISUALIZERS_PATH).instantiate()
		add_child(_list_visualizers)
		_update_visualizer_margin()

	_list_visualizers.visible = is_list_page
	# Hidden nodes keep running _process, which would keep reading the spectrum
	_list_visualizers.process_mode = Node.PROCESS_MODE_INHERIT if is_list_page else Node.PROCESS_MODE_DISABLED
	set_process(is_list_page)
