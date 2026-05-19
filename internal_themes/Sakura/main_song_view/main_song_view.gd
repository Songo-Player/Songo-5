extends MarginContainer

var current_song_duration = 1
var songo_data = SongoDataResource.get_instance()
var loaded_song = null
var panel_style

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	panel_style = %PanelContainer.get_theme_stylebox("panel")
	%PauseButton.grab_focus()
	_update_element()
	ThemeManager.theme_settings_updated.connect(_update_element)

		
func setup():
	pass
	
func _process(delta):
	update_play_time()

	
func setup_display_for(music_record: MusicRecord):
	display_play_button()
	var label_string = "%s ~ %s ~ %s" % [music_record.title, music_record.artist, music_record.album]
	%SongLabelInfo.set_carousel_text(label_string)

	if loaded_song == music_record.full_path: return

	if music_record.album_cover_texture:
		%MusicImage.show()
		%MusicImage.texture = music_record.album_cover_texture
		%PanelContainer.remove_theme_stylebox_override("panel")
		%DefaultSongImage.hide()
	else:
		%DefaultSongImage.show()
		%MusicImage.hide()
		%PanelContainer.add_theme_stylebox_override("panel", panel_style)
		
	loaded_song = music_record.full_path
	set_end_time(music_record)

func set_end_time(music_record: MusicRecord):
	var length_sec: float = music_record.raw_length
	
	if length_sec < 0: 
		%EndTimeLabel.text = "00:00"
		return
		
	current_song_duration = length_sec
	var minutes: int = int(length_sec) / 60
	var seconds: int = int(length_sec) % 60
	%EndTimeLabel.text = "%d:%02d" % [minutes, seconds]
	
func update_play_time():
	if SongoPlayerV2.is_playing():
		var pos_sec: float = SongoPlayerV2.get_playback_position()
		var minutes: int = int(pos_sec) / 60
		var seconds: int = int(pos_sec) % 60
		%CurrentTimeLabel.text = "%d:%02d" % [minutes, seconds]
		var progress_ratio = pos_sec / current_song_duration
		%ProgressLine.scale.x = progress_ratio
		
func display_play_button():
	%PlayButton.hide()
	%PauseButton.show()
	%PauseButton.grab_focus()
	
func display_pause_button():
	%PauseButton.hide()
	%PlayButton.show()
	%PlayButton.grab_focus()
	
##############################
#           SIGNALS          #
##############################

	
func _on_play_button_pressed() -> void:
	SongoPlayerV2.resume()
	display_play_button()

func _on_pause_button_pressed() -> void:
	SongoPlayerV2.pause()
	display_pause_button()
	

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

func _update_element():
	var alignment = ThemeManager.settings["content_alignment"]
	
	if alignment == "left": %AlignmentContainer.alignment = HBoxContainer.ALIGNMENT_BEGIN
	if alignment == "center": %AlignmentContainer.alignment = HBoxContainer.ALIGNMENT_CENTER
	if alignment == "right": %AlignmentContainer.alignment = HBoxContainer.ALIGNMENT_END
