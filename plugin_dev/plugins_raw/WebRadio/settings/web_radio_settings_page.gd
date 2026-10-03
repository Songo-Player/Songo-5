extends MarginContainer

## Web Radio's settings page, linked from Settings via "settings_scene_path"
## in plugin.json. Laid out like the built-in settings pages.

const WebRadioSettings = preload("web_radio_settings.gd")

var plugin
var settings

func setup(plugin_arg):
	plugin = plugin_arg
	settings = plugin.settings
	_refresh_ui()

func _ready():
	await get_tree().process_frame
	%PageLabel.grab_focus()
	%ScrollContainer.scroll_vertical = 0

func render_ui():
	pass

func handle_input(_delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.nav_back()

func _refresh_ui():
	_update_toggle(settings.auto_failover, %FailoverEnabled, %FailoverDisabled, %FailoverButton)
	_update_toggle(settings.show_stream_titles, %StreamTitlesEnabled, %StreamTitlesDisabled, %StreamTitlesButton)
	%StreamBufferLabel.text = _format_seconds(settings.stream_buffer_length)
	%NetworkTimeoutLabel.text = _format_seconds(settings.network_timeout)

func _update_toggle(enabled: bool, enabled_label: Control, disabled_label: Control, button: Button):
	enabled_label.visible = enabled
	disabled_label.visible = not enabled
	button.text = "Disable" if enabled else "Enable"

func _format_seconds(seconds: float) -> String:
	return ("%ss" % seconds) if fmod(seconds, 1.0) != 0.0 else ("%ds" % int(seconds))

func _apply():
	settings.save()
	_refresh_ui()

##############################
#           SIGNALS          #
##############################

func _on_failover_button_pressed() -> void:
	settings.auto_failover = not settings.auto_failover
	_apply()

func _on_stream_titles_button_pressed() -> void:
	settings.show_stream_titles = not settings.show_stream_titles
	_apply()

func _on_stream_buffer_down_pressed() -> void:
	settings.stream_buffer_length = WebRadioSettings.step_option(WebRadioSettings.BUFFER_OPTIONS, settings.stream_buffer_length, -1)
	_apply()

func _on_stream_buffer_up_pressed() -> void:
	settings.stream_buffer_length = WebRadioSettings.step_option(WebRadioSettings.BUFFER_OPTIONS, settings.stream_buffer_length, 1)
	_apply()

func _on_network_timeout_down_pressed() -> void:
	settings.network_timeout = WebRadioSettings.step_option(WebRadioSettings.TIMEOUT_OPTIONS, settings.network_timeout, -1)
	_apply()

func _on_network_timeout_up_pressed() -> void:
	settings.network_timeout = WebRadioSettings.step_option(WebRadioSettings.TIMEOUT_OPTIONS, settings.network_timeout, 1)
	_apply()

func _on_rebuild_station_images_button_pressed() -> void:
	plugin.rebuild_station_images()

func _on_delete_station_images_button_pressed() -> void:
	plugin.delete_station_images()

func _on_reset_to_defaults_button_pressed() -> void:
	settings.reset_to_defaults()
	_apply()
