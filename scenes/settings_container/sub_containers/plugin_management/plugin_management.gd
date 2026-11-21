extends MarginContainer

## Settings > Plugin Management: every plugin PluginManager found, with buttons
## to open its settings page, enable/disable it and delete it.

const PLUGIN_ITEM = preload("res://scenes/settings_container/sub_containers/plugin_management/plugin_item/plugin_item.tscn")
const PATH_CHIP_COLOR := Color(0.0646965, 0.0646965, 0.0646965, 1)

func setup():
	pass

func _ready():
	_build_plugin_dirs()
	_build_list()
	_link_scroll_bar()
	await get_tree().process_frame
	# The scroll bar, like the info pages, so the header shows first; left
	# jumps from it to the nearest plugin button.
	%ScrollContainer.get_v_scroll_bar().grab_focus()
	%ScrollContainer.scroll_vertical = 0

func render_ui():
	pass

func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.nav_back()

func _build_list() -> void:
	for plugin_name in PluginManager.discovered:
		var item = PLUGIN_ITEM.instantiate()
		%PluginList.add_child(item)
		item.setup(plugin_name)
		item.deleted.connect(_on_item_deleted.bind(item))
	_update_empty()

# Each folder as a dark chip; paths wrap anywhere since they rarely have spaces.
func _build_plugin_dirs() -> void:
	for dir in PluginManager.get_install_dirs():
		var chip := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = PATH_CHIP_COLOR
		style.set_corner_radius_all(4)
		style.set_content_margin_all(4)
		style.content_margin_left = 6
		style.content_margin_right = 6
		chip.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.theme_type_variation = &"SongoSettingsLabel"
		label.add_theme_font_size_override("font_size", 14)
		label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		label.text = dir
		chip.add_child(label)
		%PluginDirs.add_child(chip)


func _items() -> Array:
	return %PluginList.get_children().filter(func(c): return c.has_method("first_button") and not c.is_queued_for_deletion())

func _update_empty() -> void:
	%EmptyLabel.visible = _items().is_empty()

# Up from the first row's buttons or down from the last row's goes back to the scroll bar.
func _link_scroll_bar() -> void:
	var items := _items()
	var scroll_bar_path = %ScrollContainer.get_v_scroll_bar().get_path()
	for item in items:
		for button in item.buttons():
			button.focus_neighbor_top = scroll_bar_path if item == items.front() else NodePath()
			button.focus_neighbor_bottom = scroll_bar_path if item == items.back() else NodePath()

func _on_item_deleted(item) -> void:
	var index := _items().find(item)
	item.queue_free()
	_update_empty()
	_link_scroll_bar()
	var items := _items()
	if items.is_empty(): %ScrollContainer.get_v_scroll_bar().grab_focus()
	else: items[mini(index, items.size() - 1)].first_button().grab_focus()
