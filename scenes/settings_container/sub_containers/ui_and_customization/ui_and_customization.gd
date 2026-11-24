extends MarginContainer

var songo_settings = SongoSettings.get_instance()
var original_scale: float
var max_content_margin: int
var theme_options = []
var theme_index = 0
var _theme_setting_items = {}
const SETTING_LINE_ITEM_PATH = "res://scenes/settings_container/sub_containers/ui_and_customization/setting_line_item/setting_line_item.tscn"
const ThemePreviewOverlay = preload("res://scenes/theme_preview_overlay/theme_preview_overlay.tscn")
var _preview_overlay

const MENU_VISIBILITY_ITEMS := [
	["all_songs", "All Songs"],
	["albums", "Albums"],
	["artists", "Artists"],
	["playlists", "Playlists"],
]

func _ready():
	await get_tree().process_frame
	%PageLabel.grab_focus()
	%ScrollContainer.scroll_vertical = 0
	original_scale = songo_settings.ui_scale
	max_content_margin = int(UiHelper.content_body.size.x / 4.0)
	%ThemeSettings.sort_children.connect(_update_theme_setting_tails)
	update_current_theme_ui()
	update_clock_24_hour_ui()
	_setup_menu_visibility_settings()

func _setup_menu_visibility_settings() -> void:
	for entry in MENU_VISIBILITY_ITEMS:
		var key: String = entry[0]
		var display_name: String = entry[1]
		var setting_line_item = load(SETTING_LINE_ITEM_PATH).instantiate()
		setting_line_item.setup({
			"display_name": display_name,
			"values": [true, false],
			"labels": ["Visible", "Hidden"],
			"button_text": ["Hide", "Show"],
		}, songo_settings.menu_visibility[key])
		setting_line_item.value_updated.connect(_on_menu_visibility_updated.bind(key))
		%MenuVisibilityContainer.add_child(setting_line_item)

func _on_menu_visibility_updated(new_value, key: String) -> void:
	songo_settings.menu_visibility[key] = new_value
	songo_settings.save()

func _on_theme_setting_value_updated(new_value, key):
	print("Updating: %s, %s" % [key, new_value])

	ThemeManager.settings[key] = new_value
	ThemeManager.save_theme_settings()
	_update_theme_setting_visibility()

func _update_theme_setting_visibility() -> void:
	# Items are in display order, so a setting's parent has already been updated.
	for key in _theme_setting_items:
		var parent: String = ThemeManager.get_setting_parent(key)
		var parent_visible: bool = parent == "" or _theme_setting_items[parent].visible
		_theme_setting_items[key].visible = parent_visible and ThemeManager.is_setting_visible(key)

func _update_theme_setting_tails() -> void:
	for key in _theme_setting_items:
		var parent: String = ThemeManager.get_setting_parent(key)
		if parent == "": continue
		var item: Control = _theme_setting_items[key]
		var parent_item: Control = _theme_setting_items[parent]
		item.set_tail_reach(item.position.y - parent_item.position.y - parent_item.size.y)

# Theme settings in definition order, except that each is moved directly below
# the setting it depends on. Returns { key: nesting depth }, in display order.
func _get_theme_settings_display_order() -> Dictionary:
	var dependents := {}
	var top_level := []
	for key in ThemeManager.settings_info:
		if not ThemeManager.settings.has(key): continue
		var parent: String = ThemeManager.get_setting_parent(key)
		if parent == "":
			top_level.append(key)
		else:
			if not dependents.has(parent): dependents[parent] = []
			dependents[parent].append(key)

	var order := {}
	for key in top_level:
		_add_to_display_order(key, 0, dependents, order)
	# Settings that depend on each other in a loop are never reached from the top
	# level. It's a mistake in the theme, but they should still be shown.
	for parent in dependents:
		for key in dependents[parent]:
			_add_to_display_order(key, 0, dependents, order)
	return order

func _add_to_display_order(key: String, depth: int, dependents: Dictionary, order: Dictionary) -> void:
	if order.has(key): return
	order[key] = depth
	for dependent in dependents.get(key, []):
		_add_to_display_order(dependent, depth + 1, dependents, order)

func setup():
	theme_options = get_theme_options()
	# The theme in use, which is the default theme until one is picked
	var possible_index = theme_options.find(ThemeManager.theme_path)
	if possible_index >= 0: theme_index = possible_index
	update_global_scale_ui()
	update_content_margin_ui()
	
func render_ui():
	pass

func get_theme_options_OLD():
	var dirs: Array[String] = []
	var path = "res://internal_themes"

	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Failed to open directory: " + path)
		return dirs

	dir.list_dir_begin()
	var name := dir.get_next()

	while name != "":
		if dir.current_is_dir() and name != "." and name != "..":
			dirs.append(path + "/" + name)
		name = dir.get_next()

	dir.list_dir_end()
	print(dirs)
	return dirs

func get_theme_options():
	var dirs: Array[String] = [
		"res://internal_themes/SongoClassic",
		"res://internal_themes/Sakura",
		"res://internal_themes/XBop",
		"res://internal_themes/Ringing",
	]
	
		
	var paths := ["user://external_themes"]
	# external themes sbc is just an easy way to include some themes
	var external_themes_sbc: String = ThemeManager.find_songo_themes_dir()
	if external_themes_sbc != "":
		paths.append(external_themes_sbc)
		
	for path in paths:
		var dir := DirAccess.open(path)
		if dir == null:
			push_error("Failed to open directory: " + path)
			continue
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if dir.current_is_dir() and name != "." and name != "..":
				dirs.append(path + "/" + name)
			name = dir.get_next()
		dir.list_dir_end()
	return dirs
	
	
func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.nav_back()
		
# Change opens the theme preview overlay on the theme in use; the arrows step
# through every theme and Apply switches to the one showing.
func update_theme_options_ui():
	if _preview_overlay == null: return
	var displayed_theme = theme_options[theme_index]
	var theme_info = ThemeManager.parse_theme_json(displayed_theme)
	var preview_path = displayed_theme + "/preview.png"
	var tex: Texture2D = null
	if preview_path.begins_with("res://"):
		if ResourceLoader.exists(preview_path): tex = load(preview_path)
	else:
		var img := Image.load_from_file(preview_path)
		if img != null:
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		push_error("Failed to load preview image: " + preview_path)

	var in_use: bool = displayed_theme == ThemeManager.theme_path
	_preview_overlay.display({
		"name": theme_info.get("name", ""),
		"version": theme_info.get("version", ""),
		"author": theme_info.get("author", ""),
		"co_authors": theme_info.get("co_authors", []) if typeof(theme_info.get("co_authors")) == TYPE_ARRAY else [],
		"description": theme_info.get("description", ""),
		"preview": tex,
		"tags": theme_info.get("tags", []),
		"ai_usage": theme_info.get("ai_usage"),
		"status": "This is the theme you're using." if in_use else "",
		"status_kind": "good",
		"action": "Apply",
		"action_disabled": in_use,
		"can_navigate": theme_options.size() > 1,
	})

func _open_theme_preview():
	_preview_overlay = ThemePreviewOverlay.instantiate()
	_preview_overlay.navigated.connect(_on_theme_navigated)
	_preview_overlay.action_pressed.connect(_on_apply_theme_pressed)
	_preview_overlay.closed.connect(func(): _preview_overlay = null)
	_preview_overlay.open()
	update_theme_options_ui()

func _on_theme_navigated(step: int):
	theme_index = posmod(theme_index + step, theme_options.size())
	update_theme_options_ui()

func update_current_theme_ui():
	var theme_info = ThemeManager.parse_theme_json(ThemeManager.theme_path)
	%ThemeDisplayLabel.text = theme_info["name"]
	%ThemeSettingsLabel.text = "%s - Theme Settings" % theme_info["name"]
	print(theme_options)
	for child in %ThemeSettings.get_children():
		child.queue_free()
	_theme_setting_items = {}
	await get_tree().process_frame
	if ThemeManager.settings != {}:
		%ThemeSettingsContainer.show()
		var display_order := _get_theme_settings_display_order()
		for key in display_order:
			var info = ThemeManager.settings_info[key]
			var value = ThemeManager.settings[key]
			var setting_line_item = load(SETTING_LINE_ITEM_PATH).instantiate()
			setting_line_item.setup(info, value)
			%ThemeSettings.add_child(setting_line_item)
			setting_line_item.set_dependent_depth(display_order[key])
			setting_line_item.value_updated.connect(_on_theme_setting_value_updated.bind(key))
			_theme_setting_items[key] = setting_line_item
		_update_theme_setting_visibility()

	%NoSettingsLabel.visible = ThemeManager.settings == {}
	
func update_content_margin_ui():
	%ContentMarginDisplayLabel.text = "%dpx" % songo_settings.content_margin

func update_clock_24_hour_ui():
	%Clock24HourDisplayLabel.text = "24 Hour" if songo_settings.clock_24_hour else "12 Hour"

func _on_clock_24_hour_down_pressed() -> void:
	_toggle_clock_24_hour()

func _on_clock_24_hour_up_pressed() -> void:
	_toggle_clock_24_hour()

func _toggle_clock_24_hour() -> void:
	songo_settings.clock_24_hour = not songo_settings.clock_24_hour
	songo_settings.save()
	update_clock_24_hour_ui()

func update_global_scale_ui():
	%GlobalScaleDisplayLabel.text = "%.2fx" % songo_settings.ui_scale 
		
func _on_global_ui_scale_down_pressed() -> void:
	songo_settings.ui_scale = clamp(songo_settings.ui_scale - 0.05, 0.5, 1.5)
	_apply_global_ui_scale()

func _on_global_ui_scale_up_pressed() -> void:
	songo_settings.ui_scale = clamp(songo_settings.ui_scale + 0.05, 0.5, 1.5)
	_apply_global_ui_scale()

func _apply_global_ui_scale() -> void:
	update_global_scale_ui()
	songo_settings.save()
	UiHelper.apply_scale(songo_settings.ui_scale)

func _on_reset_to_defaults_button_pressed() -> void:
	songo_settings.ui_scale = 1.0
	songo_settings.content_margin = 16
	songo_settings.save()
	
	#UiHelper.update_os_time()
	UiHelper.apply_scale(songo_settings.ui_scale)
	UiHelper.apply_content_margin(songo_settings.content_margin)
	
	update_global_scale_ui()
	update_content_margin_ui()

func _on_tree_entered() -> void:
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

func _on_tree_exiting() -> void:
	get_viewport().gui_focus_changed.disconnect(_on_focus_changed)

func _on_focus_changed(item: Control):
	if item == %ResetToDefaultsButton:
		%ScrollContainer.scroll_vertical = 999

func _on_content_margin_down_pressed() -> void:
	songo_settings.content_margin = clamp(songo_settings.content_margin - _get_content_margin_adjustment(), 0, max_content_margin)
	_apply_content_margin()
	
func _on_content_margin_up_pressed() -> void:
	songo_settings.content_margin = clamp(songo_settings.content_margin + _get_content_margin_adjustment(), 0, max_content_margin)
	_apply_content_margin()
	
func _get_content_margin_adjustment():
	if songo_settings.content_margin >= 64: return 4
	if songo_settings.content_margin >= 16: return 2
	return 1
	
func _apply_content_margin():
	songo_settings.save()
	UiHelper.apply_content_margin(songo_settings.content_margin)
	update_content_margin_ui()


func _on_apply_theme_pressed() -> void:
	if _preview_overlay != null: _preview_overlay.close()
	songo_settings.theme_path = theme_options[theme_index]
	songo_settings.save()
	if ThemeManager.theme_path != theme_options[theme_index]:
		ThemeManager.set_current_theme(theme_options[theme_index])
		Controller.history = []
		SongoPlayer.stop()
		Controller.main_menu()
	else:
		UiHelper.flash_message("This theme is already being applied")

func _on_settings_button_pressed() -> void:
	var current = theme_options.find(ThemeManager.theme_path)
	if current >= 0: theme_index = current
	_open_theme_preview()
