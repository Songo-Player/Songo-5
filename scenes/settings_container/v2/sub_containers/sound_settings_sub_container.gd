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

		
func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.new_nav_back()
		
func update_sfx_volume_ui():
	%SfxVolumeDisplayLabel.text = "%d%%" % int(round(songo_settings.sfx_volume * 100))

func update_music_volume_ui():
	%MusicVolumeDisplayLabel.text = "%d%%" % int(round(songo_settings.music_volume * 100))

func update_stream_buffer_length_ui():
	%BufferLengthLabel.text = "%dms" % songo_settings.stream_buffer_length
	
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

func _on_reset_to_defaults_button_pressed() -> void:
	songo_settings.sfx_volume = 1.0
	songo_settings.music_volume = 1.0
	songo_settings.stream_buffer_length = 100
	songo_settings.save()
	_ui_settings_refresh()
