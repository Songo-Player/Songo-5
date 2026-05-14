extends MarginContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_on_clock_timer_timeout()
	_update_element()
	await get_tree().process_frame
	%AllSongsButton.grab_focus()

func _on_clock_timer_timeout() -> void:
	var now = Time.get_datetime_dict_from_system()
	var hour_12 = now.hour % 12
	if hour_12 == 0: hour_12 = 12
	var hour = str(hour_12).pad_zeros(2)
	var minute = str(now.minute).pad_zeros(2)
	var am_pm = "am"
	if now.hour >= 12: am_pm = "pm"
	
	%HourLabel.text = hour
	%MinuteLabel.text = minute
	%AmPmLabel.text = am_pm


func _on_settings_button_pressed() -> void:
	Controller.settings_index()


func _on_all_songs_button_focus_entered() -> void:
	%CurrentMenuItemLabel.text = "All Songs"

func _on_albums_button_focus_entered() -> void:
	%CurrentMenuItemLabel.text = "Albums"

func _on_artists_button_focus_entered() -> void:
	%CurrentMenuItemLabel.text = "Artists"

func _on_playlists_button_focus_entered() -> void:
	%CurrentMenuItemLabel.text = "Playlists"

func _on_settings_button_focus_entered() -> void:
	%CurrentMenuItemLabel.text = "Settings"

func _on_exit_button_focus_entered() -> void:
	%CurrentMenuItemLabel.text = "Exit"

func _on_exit_button_pressed() -> void:
	Controller.quit_songo()

func _on_all_songs_button_pressed() -> void:
	Controller.songs_index()

func _on_albums_button_pressed() -> void:
	Controller.albums_index()

func _on_artists_button_pressed() -> void:
	Controller.artists_index()

func _on_playlists_button_pressed() -> void:
	Controller.playlists_index()

func _update_element():
	var alignment = ThemeManager.settings["content_alignment"]
	
	if alignment == "left": %AlignmentContainer.alignment = HBoxContainer.ALIGNMENT_BEGIN
	if alignment == "center": %AlignmentContainer.alignment = HBoxContainer.ALIGNMENT_CENTER
	if alignment == "right": %AlignmentContainer.alignment = HBoxContainer.ALIGNMENT_END


func _on_tree_entered() -> void:
	_update_element()
