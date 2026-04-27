extends MarginContainer

var songo_settings = SongoSettings.get_instance()
var original_scale: float
var max_content_margin: int

func _ready():
	await get_tree().process_frame
	%PageLabel.grab_focus()
	%ScrollContainer.scroll_vertical = 0
	original_scale = songo_settings.ui_scale
	max_content_margin = int(UiHelper.content_body.size.x / 4.0)

func setup():
	update_global_scale_ui()
	update_theme_color_preview()
	update_main_menu_size_ui()
	update_clock_setting_ui()
	update_all_songs_menu_nav_ui()
	update_albums_menu_nav_ui()
	update_artists_menu_nav_ui()
	update_playlists_menu_nav_ui()
	update_content_margin_ui()
	
func render_ui():
	pass

func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		if songo_settings.ui_scale == original_scale:
			Controller.new_nav_back()
		else:
			print("Ui Scale change, force reload settings")
			Controller.nav_back_to_settings()
		

func update_content_margin_ui():
	%ContentMarginDisplayLabel.text = "%dpx" % songo_settings.content_margin
	
func update_global_scale_ui():
	%GlobalScaleDisplayLabel.text = "%.2fx" % songo_settings.ui_scale 

func update_theme_color_preview():
	%ThemeColorDisplayLabel.text = songo_settings.theme_color_name

func update_main_menu_size_ui():
	var size_text = ["SM", "MD", "LG"][songo_settings.main_menu_size]
	%MainMenuSizeLabel.text = size_text

func update_clock_setting_ui():
	if songo_settings.clock_24_hour:
		%Clock24HourEnabled.show()
		%Clock24HourDisabled.hide()
		%Clock24HourButton.text = "Disable"
	else:
		%Clock24HourEnabled.hide()
		%Clock24HourDisabled.show()
		%Clock24HourButton.text = "Enable"
		
func update_all_songs_menu_nav_ui():
	if songo_settings.main_menu_visible["all_songs"] == true:
		%AllSongsMenuNavEnabled.show()
		%AllSongsMenuNavDisabled.hide()
		%AllSongsMenuNavButton.text = "Hide"
	else:
		%AllSongsMenuNavEnabled.hide()
		%AllSongsMenuNavDisabled.show()
		%AllSongsMenuNavButton.text = "Show"
		
func update_albums_menu_nav_ui():
	if songo_settings.main_menu_visible["albums"] == true:
		%AlbumsMenuNavEnabled.show()
		%AlbumsMenuNavDisabled.hide()
		%AlbumsMenuNavButton.text = "Hide"
	else:
		%AlbumsMenuNavEnabled.hide()
		%AlbumsMenuNavDisabled.show()
		%AlbumsMenuNavButton.text = "Show"
		
func update_artists_menu_nav_ui():
	if songo_settings.main_menu_visible["artists"] == true:
		%ArtistsMenuNavEnabled.show()
		%ArtistsMenuNavDisabled.hide()
		%ArtistsMenuNavButton.text = "Hide"
	else:
		%ArtistsMenuNavEnabled.hide()
		%ArtistsMenuNavDisabled.show()
		%ArtistsMenuNavButton.text = "Show"

func update_playlists_menu_nav_ui():
	if songo_settings.main_menu_visible["playlists"] == true:
		%PlaylistsMenuNavEnabled.show()
		%PlaylistsMenuNavDisabled.hide()
		%PlaylistsMenuNavButton.text = "Hide"
	else:
		%PlaylistsMenuNavEnabled.hide()
		%PlaylistsMenuNavDisabled.show()
		%PlaylistsMenuNavButton.text = "Show"
		
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

func _on_theme_color_down_pressed() -> void:
	songo_settings.theme_color_index -= 1
	if songo_settings.theme_color_index < 0: songo_settings.theme_color_index = songo_settings.THEME_COLORS.size()-1
	_apply_theme_color()

func _on_theme_color_up_pressed() -> void:
	songo_settings.theme_color_index += 1
	if songo_settings.theme_color_index >= songo_settings.THEME_COLORS.size(): songo_settings.theme_color_index = 0
	_apply_theme_color()
	
func _apply_theme_color() -> void:
	songo_settings.save()
	UiHelper.apply_theme_color(songo_settings.theme_color)
	update_theme_color_preview()


func _on_main_menu_size_down_pressed() -> void:
	songo_settings.main_menu_size -= 1
	if songo_settings.main_menu_size < 0: songo_settings.main_menu_size = 2
	songo_settings.save()
	update_main_menu_size_ui()

func _on_main_menu_size_up_pressed() -> void:
	songo_settings.main_menu_size += 1
	if songo_settings.main_menu_size > 2: songo_settings.main_menu_size = 0
	songo_settings.save()
	update_main_menu_size_ui()

func _on_clock_24_hour_button_pressed() -> void:
	songo_settings.clock_24_hour = not songo_settings.clock_24_hour
	songo_settings.save()
	UiHelper.update_os_time()
	update_clock_setting_ui()

func _on_reset_to_defaults_button_pressed() -> void:
	songo_settings.ui_scale = 1.0
	songo_settings.theme_color_index = 0
	songo_settings.clock_24_hour = false
	songo_settings.main_menu_size = 1
	songo_settings.content_margin = 16
	songo_settings.main_menu_visible = {
		"all_songs": true,
		"albums": true,
		"artists": true,
		"playlists": true
	}
	songo_settings.save()
	
	UiHelper.update_os_time()
	UiHelper.apply_theme_color(songo_settings.theme_color)
	UiHelper.apply_scale(songo_settings.ui_scale)
	UiHelper.apply_content_margin(songo_settings.content_margin)
	
	update_global_scale_ui()
	update_theme_color_preview()
	update_clock_setting_ui()
	update_main_menu_size_ui()
	update_all_songs_menu_nav_ui()
	update_albums_menu_nav_ui()
	update_artists_menu_nav_ui()
	update_playlists_menu_nav_ui()
	update_content_margin_ui()

func _on_tree_entered() -> void:
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

func _on_tree_exiting() -> void:
	get_viewport().gui_focus_changed.disconnect(_on_focus_changed)

func _on_focus_changed(item: Control):
	if item == %ResetToDefaultsButton:
		%ScrollContainer.scroll_vertical = 999


func _on_all_songs_menu_nav_button_pressed() -> void:
	songo_settings.main_menu_visible["all_songs"] = not songo_settings.main_menu_visible["all_songs"]
	songo_settings.save()
	update_all_songs_menu_nav_ui()


func _on_albums_menu_nav_button_pressed() -> void:
	songo_settings.main_menu_visible["albums"] = not songo_settings.main_menu_visible["albums"]
	songo_settings.save()
	update_albums_menu_nav_ui()


func _on_artists_menu_nav_button_pressed() -> void:
	songo_settings.main_menu_visible["artists"] = not songo_settings.main_menu_visible["artists"]
	songo_settings.save()
	update_artists_menu_nav_ui()


func _on_playlists_menu_nav_button_pressed() -> void:
	songo_settings.main_menu_visible["playlists"] = not songo_settings.main_menu_visible["playlists"]
	songo_settings.save()
	update_playlists_menu_nav_ui()


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
