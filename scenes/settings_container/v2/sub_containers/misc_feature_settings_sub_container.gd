extends MarginContainer

var songo_settings = SongoSettings.get_instance()

func setup():
	update_song_following_ui()
	update_song_sleep_ui()
	update_song_sleep_type_ui()
	
func _ready():
	await get_tree().process_frame
	%PageLabel.grab_focus()
	%ScrollContainer.scroll_vertical = 0

func render_ui():
	pass
	
func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.new_nav_back()
		
func update_song_sleep_type_ui():
	%SongSleepFadeTypeLabel.text = songo_settings.song_sleep_type_name
		
func update_song_sleep_ui():
	if songo_settings.song_sleep_timer == 99999:
		%SongSleepTimerLabel.text = "NO"
	else:
		%SongSleepTimerLabel.text = "%ds" % songo_settings.song_sleep_timer
	
func update_song_following_ui():
	if songo_settings.song_following:
		%SongFollowingEnabled.show()
		%SongFollowingDisabled.hide()
		%SongFollowingButton.text = "Disable"
	else:
		%SongFollowingEnabled.hide()
		%SongFollowingDisabled.show()
		%SongFollowingButton.text = "Enable"

func _on_song_following_button_pressed() -> void:
	songo_settings.song_following = not songo_settings.song_following
	update_song_following_ui()

func _on_song_sleep_timer_down_pressed() -> void:
	songo_settings.song_sleep_timer_index -= 1
	if songo_settings.song_sleep_timer_index < 0: songo_settings.song_sleep_timer_index = songo_settings.SONG_SLEEP_TIMES.size()-1
	_apply_song_sleep_timer()
	
func _on_song_sleep_timer_up_pressed() -> void:
	songo_settings.song_sleep_timer_index += 1
	if songo_settings.song_sleep_timer_index >= songo_settings.SONG_SLEEP_TIMES.size(): songo_settings.song_sleep_timer_index = 0
	_apply_song_sleep_timer()
	
func _apply_song_sleep_timer() -> void:
	songo_settings.save()
	update_song_sleep_ui()

func _on_song_sleep_fade_type_up_pressed() -> void:
	var initial_type = songo_settings.song_sleep_type
	songo_settings.song_sleep_type +=1
	if songo_settings.song_sleep_type > 2: songo_settings.song_sleep_type = 0
	_apply_song_sleep_type(initial_type)

func _apply_song_sleep_type(initial_type: int):
	if DeviceOS.no_bright_fade_available == true:
		if initial_type == 1: songo_settings.song_sleep_type = 2
		else: songo_settings.song_sleep_type = 1
		UiHelper.flash_message("Your CFW lacks advanced support, 'Black Fade' or 'Disabled' allowed.")
	update_song_sleep_type_ui()
	songo_settings.save()

func _on_song_sleep_fade_type_down_pressed() -> void:
	var initial_type = songo_settings.song_sleep_type
	songo_settings.song_sleep_type -=1
	if songo_settings.song_sleep_type < 0: songo_settings.song_sleep_type = 2
	_apply_song_sleep_type(initial_type)
	
func _on_tree_entered() -> void:
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

func _on_tree_exiting() -> void:
	get_viewport().gui_focus_changed.disconnect(_on_focus_changed)

func _on_focus_changed(item: Control):
	if item == %SongFollowingButton:
		%ScrollContainer.scroll_vertical = 0
	if item == %SongSleepTimerDown || item == %SongSleepTimerUp:
		%ScrollContainer.scroll_vertical = 999
