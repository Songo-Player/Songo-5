extends MarginContainer

## About Songo#5: app version, runtime, device and library info, laid out like
## the song info panel. Opened by pressing Select on the main menu while no
## music is playing; Back or Select closes it.
##     load("res://scenes/app_info_panel/app_info_panel.tscn").instantiate().open()

# Margin around the card at 4:3; wider screens add to the sides.
const CARD_MARGIN := 50

var songo_data = SongoDataResource.get_instance()

# Frame the panel opened on; the select press that opened it is still "just
# pressed" when _process runs later that frame.
var _opened_frame := -1
var _open := false
# Main UI control that had focus, given back on close.
var _focus_return: Control = null

func open() -> void:
	_opened_frame = Engine.get_process_frames()
	_open = true
	_focus_return = UiHelper.content_body.get_viewport().gui_get_focus_owner()
	UiHelper.open_overlay_panel(self)
	resized.connect(_cap_card_width)
	_cap_card_width()
	_fill_info()
	# Keep the main menu's focused button from being pressed underneath.
	UiHelper.overlay_window.grab_focus()

func close() -> void:
	if not _open: return
	_open = false
	UiHelper.close_overlay_panel(self)
	if is_instance_valid(_focus_return): _focus_return.grab_focus()

func _process(_delta: float) -> void:
	if not _open or Engine.get_process_frames() == _opened_frame: return
	if Input.is_action_just_pressed("back") || Input.is_action_just_pressed("select"):
		close()

func _cap_card_width() -> void:
	var side := UiHelper.capped_card_side_margin(size, CARD_MARGIN)
	$MarginContainer.add_theme_constant_override("margin_left", side)
	$MarginContainer.add_theme_constant_override("margin_right", side)

func _fill_info() -> void:
	%VersionLabel.set_carousel_text(SongoDataResource.VERSION)
	%RuntimeLabel.set_carousel_text("Songodot %s" % Engine.get_version_info().get("string", "?"))
	%PlatformLabel.set_carousel_text(DeviceOS.get_os_name())
	%DeviceLabel.set_carousel_text(_or_unknown(DeviceOS.device_name))
	%ProcessorLabel.set_carousel_text(_or_unknown(OS.get_processor_name()))

	%SongCountLabel.text = str(songo_data.music_records.size())
	%MusicDirCountLabel.text = str(songo_data.music_directory_paths.size())
	%DataFormatLabel.text = SongoDataResource.DATA_VERSION
	%SettingsFormatLabel.text = SongoSettings.SETTINGS_VERSION
	%BackgroundPlayLabel.text = "Available" if SongoPlayer.bg_play_enabled() else "Unavailable"
	var window := DisplayServer.window_get_size()
	%ScreenLabel.text = "%dx%d" % [window.x, window.y]
	%GpuLabel.text = _or_unknown(RenderingServer.get_video_adapter_name())
	%BootTimeLabel.text = _seconds(UiHelper.boot_msec)
	%ImportTimeLabel.text = _seconds(songo_data.last_import_msec) if songo_data.last_import_msec >= 0 else "None yet"

func _seconds(msec: int) -> String:
	return "%.2fs" % (msec / 1000.0)

func _or_unknown(value: String) -> String:
	return value if value.strip_edges() != "" else "Unknown"
