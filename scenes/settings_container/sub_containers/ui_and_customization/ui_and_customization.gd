extends MarginContainer

var songo_settings = SongoSettings.get_instance()
var original_scale: float
var max_content_margin: int
var theme_options = []
var theme_index = 0
const SETTING_LINE_ITEM_PATH = "res://scenes/settings_container/sub_containers/ui_and_customization/setting_line_item/setting_line_item.tscn"
const THEME_TAG_PATH = "res://scenes/settings_container/sub_containers/ui_and_customization/theme_tag/theme_tag.tscn"

func _ready():
	await get_tree().process_frame
	%PageLabel.grab_focus()
	%ScrollContainer.scroll_vertical = 0
	original_scale = songo_settings.ui_scale
	max_content_margin = int(UiHelper.content_body.size.x / 4.0)
	update_theme_options_ui()
	update_current_theme_ui()

func _on_theme_setting_value_updated(new_value, key):
	print("Updating: %s, %s" % [key, new_value])

	ThemeManager.settings[key] = new_value
	ThemeManager.save_theme_settings()
	
func setup():
	theme_options = get_theme_options()
	var possible_index = theme_options.find(songo_settings.theme_path)
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

func _find_songo_themes_dir() -> String:
	var base := OS.get_executable_path().get_base_dir()
	for i in range(4):  # adjacent (0 levels up) + up to 3 levels above
		var candidate := base + "/songo_themes"
		if DirAccess.dir_exists_absolute(candidate):
			return candidate
		base = base.get_base_dir()
	return ""

func get_theme_options():
	var dirs: Array[String] = [
		"res://internal_themes/SongoClassic",
		"res://internal_themes/Sakura",
		"res://internal_themes/XBop",
		"res://internal_themes/Ringing",
	]
	
		
	var paths := ["user://external_themes"]
	# external themes sbc is just an easy way to include some themes
	var external_themes_sbc := _find_songo_themes_dir()
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
		
func update_theme_options_ui():
	var displayed_theme = theme_options[theme_index]
	var theme_info = ThemeManager.parse_theme_json(displayed_theme)
	var preview_path = displayed_theme + "/preview.png"
	var tex: Texture2D = null
	if preview_path.begins_with("res://"):
		tex = load(preview_path)
	else:
		var img := Image.load_from_file(preview_path)
		if img != null:
			tex = ImageTexture.create_from_image(img)

	if tex == null:
		push_error("Failed to load preview image: " + preview_path)
	else:
		%ThemePreviewImage.texture = tex
		
	%ThemeNameWithVersion.text = "%s (v%s)" % [theme_info['name'], theme_info['version']]
	%ThemeAuthor.text = "Created by %s" % theme_info["author"]
	%ThemeDescription.text = theme_info["description"]
	
	for child in %ThemeTagContainer.get_children():
		child.queue_free()
		
	await get_tree().process_frame
	
	if theme_info.has("tags"):
		for tag in theme_info["tags"]:
			var theme_tag = load(THEME_TAG_PATH).instantiate()
			theme_tag.setup(tag)
			%ThemeTagContainer.add_child(theme_tag)
	
func update_current_theme_ui():
	var theme_info = ThemeManager.parse_theme_json(songo_settings.theme_path)
	%ThemeDisplayLabel.text = theme_info["name"]
	%ThemeSettingsLabel.text = "%s - Theme Settings" % theme_info["name"]
	print(theme_options)
	for child in %ThemeSettings.get_children():
		child.queue_free()
	await get_tree().process_frame
	if ThemeManager.settings != {}:
		%ThemeSettingsContainer.show()
		# Use settings info to retain order of defined settings
		for key in ThemeManager.settings_info.keys():
			if not ThemeManager.settings.has(key): continue
			var info = ThemeManager.settings_info[key]
			var value = ThemeManager.settings[key]
			var setting_line_item = load(SETTING_LINE_ITEM_PATH).instantiate()
			setting_line_item.setup(info, value)
			%ThemeSettings.add_child(setting_line_item)
			setting_line_item.value_updated.connect(_on_theme_setting_value_updated.bind(key))

	%NoSettingsLabel.visible = ThemeManager.settings == {}
	
func update_content_margin_ui():
	%ContentMarginDisplayLabel.text = "%dpx" % songo_settings.content_margin
	
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
	
	UiHelper.update_os_time()
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
	songo_settings.theme_path = theme_options[theme_index]
	songo_settings.save()
	if ThemeManager.theme_path != theme_options[theme_index]:
		ThemeManager.set_current_theme(theme_options[theme_index])
		Controller.history = []
		SongoPlayerV2.stop()
		Controller.main_menu()
	else:
		UiHelper.flash_message("This theme is already being applied")

func _on_theme_down_pressed() -> void:
	theme_index = theme_index-1
	if theme_index < 0: theme_index = theme_options.size()-1
	update_theme_options_ui()

func _on_theme_up_pressed() -> void:
	theme_index = theme_index+1
	if theme_index >= theme_options.size(): theme_index = 0
	update_theme_options_ui()


func _on_settings_button_pressed() -> void:
	%ThemePickerContainer.visible = not %ThemePickerContainer.visible
	if %ThemePickerContainer.visible: %SettingsButton.text = "Hide"
	else: %SettingsButton.text = "Change"
