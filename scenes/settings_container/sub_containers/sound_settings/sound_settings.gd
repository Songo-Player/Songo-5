extends MarginContainer

var songo_settings = SongoSettings.get_instance()

func setup():
	_ui_settings_refresh()
	
func _ready():
	await get_tree().process_frame
	%PageLabel.grab_focus()
	%ScrollContainer.scroll_vertical = 0

func render_ui():
	pass
	
func _ui_settings_refresh():
	update_sfx_volume_ui()
	update_stream_buffer_length_ui()
	update_music_volume_ui()
	update_playback_blend_ui()
	update_use_equalizer_ui()
	update_eq_ui()

		
func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.nav_back()
		
func update_sfx_volume_ui():
	%SfxVolumeDisplayLabel.text = "%d%%" % int(round(songo_settings.sfx_volume * 100))

func update_music_volume_ui():
	%MusicVolumeDisplayLabel.text = "%d%%" % int(round(songo_settings.music_volume * 100))

func update_stream_buffer_length_ui():
	%BufferLengthLabel.text = "%dms" % songo_settings.stream_buffer_length

func update_playback_blend_ui():
	%PlaybackBlendDisplayLabel.text = "%.1fs" % songo_settings.playback_blend_time

func update_use_equalizer_ui():
	if songo_settings.use_equalizer:
		%UseEqualizerEnabled.show()
		%UseEqualizerDisabled.hide()
		%UseEqualizerButton.text = "Disable"
		%EQBandsContainer.show()
	else:
		%UseEqualizerEnabled.hide()
		%UseEqualizerDisabled.show()
		%UseEqualizerButton.text = "Enable"
		%EQBandsContainer.hide()

func _on_use_equalizer_button_pressed() -> void:
	songo_settings.use_equalizer = not songo_settings.use_equalizer
	songo_settings.save()
	SongoPlayerV2.apply_equalizer_settings()
	update_use_equalizer_ui()

func update_eq_ui():
	for band_index in range(1, SongoEqualizer.BAND_COUNT + 1):
		var line_edit = get_node_or_null("%%Band%dDecibalAdjustment" % band_index)
		if line_edit:
			line_edit.text = "%+ddb" % int(round(songo_settings.equalizer.get_band_gain(band_index - 1)))

func _on_tree_entered() -> void:
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

func _on_tree_exiting() -> void:
	get_viewport().gui_focus_changed.disconnect(_on_focus_changed)

func _on_focus_changed(item: Control):
	if item == %ABLayoutButton:
		%ScrollContainer.scroll_vertical = 0
	if item == %ResetToDefaultsButton:
		%ScrollContainer.scroll_vertical = 999

func _on_sfx_volume_down_pressed() -> void:
	songo_settings.sfx_volume = clamp(songo_settings.sfx_volume - 0.1, 0, 2.0)
	songo_settings.save()
	SfxPlayer.set_vol(songo_settings.sfx_volume)
	update_sfx_volume_ui()

func _on_sfx_volume_up_pressed() -> void:
	songo_settings.sfx_volume = clamp(songo_settings.sfx_volume + 0.1, 0, 2.0)
	songo_settings.save()
	SfxPlayer.set_vol(songo_settings.sfx_volume)
	update_sfx_volume_ui()
	
func _on_music_volume_down_pressed() -> void:
	songo_settings.music_volume = clamp(songo_settings.music_volume - 0.1, 0, 2.0)
	songo_settings.save()
	SongoPlayerV2.set_vol(songo_settings.music_volume)
	update_music_volume_ui()

func _on_music_volume_up_pressed() -> void:
	songo_settings.music_volume = clamp(songo_settings.music_volume + 0.1, 0, 2.0)
	songo_settings.save()
	SongoPlayerV2.set_vol(songo_settings.music_volume)
	update_music_volume_ui()

func _on_buffer_length_down_pressed() -> void:
	songo_settings.stream_buffer_length -= 5
	if songo_settings.stream_buffer_length <= 0:
		songo_settings.stream_buffer_length = 500
	_update_buffer_length()
	
func _on_buffer_length_up_pressed() -> void:
	songo_settings.stream_buffer_length += 5
	if songo_settings.stream_buffer_length >= 505:
		songo_settings.stream_buffer_length = 5
	_update_buffer_length()
	
func _update_buffer_length():
	songo_settings.save()
	SongoPlayerV2.ffmpeg_audio_playback.set_buffer_length_ms(songo_settings.stream_buffer_length)
	var target_playback = SongoPlayerV2.get_playback_position()
	SongoPlayerV2.ffmpeg_audio_playback.seek(target_playback)
	update_stream_buffer_length_ui()

func _on_playback_blend_down_pressed() -> void:
	songo_settings.playback_blend_time = clamp(songo_settings.playback_blend_time - 0.5, 0.0, 15.0)
	songo_settings.save()
	update_playback_blend_ui()

func _on_playback_blend_up_pressed() -> void:
	songo_settings.playback_blend_time = clamp(songo_settings.playback_blend_time + 0.5, 0.0, 15.0)
	songo_settings.save()
	update_playback_blend_ui()

func _on_eq_band_down_pressed(band_number: int) -> void:
	_adjust_eq_band(band_number, -1.0)

func _on_eq_band_up_pressed(band_number: int) -> void:
	_adjust_eq_band(band_number, 1.0)

func _adjust_eq_band(band_number: int, delta_db: float) -> void:
	var band_index = band_number - 1
	var new_gain = songo_settings.equalizer.get_band_gain(band_index) + delta_db
	if new_gain > SongoEqualizer.MAX_GAIN_DB:
		new_gain = SongoEqualizer.MIN_GAIN_DB
	elif new_gain < SongoEqualizer.MIN_GAIN_DB:
		new_gain = SongoEqualizer.MAX_GAIN_DB
	songo_settings.equalizer.set_band_gain(band_index, new_gain)
	songo_settings.save()
	SongoPlayerV2.apply_equalizer_settings()
	update_eq_ui()

func _on_reset_to_defaults_button_pressed() -> void:
	songo_settings.sfx_volume = 1.0
	songo_settings.music_volume = 1.0
	songo_settings.stream_buffer_length = 100
	songo_settings.playback_blend_time = 4.0
	songo_settings.use_equalizer = false
	songo_settings.equalizer.reset()
	songo_settings.save()
	SongoPlayerV2.apply_equalizer_settings()
	_ui_settings_refresh()
