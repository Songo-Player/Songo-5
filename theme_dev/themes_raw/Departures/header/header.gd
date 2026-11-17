extends MarginContainer
## Top strip: the platform sign on the left, network, battery and a split-flap
## clock on the right. The clock only flips when the minute actually changes.

const P = preload("../assets/palette.gd")

var _battery_thread: Thread

func _ready() -> void:
	_apply_settings()
	ThemeManager.theme_settings_updated.connect(_apply_settings)
	_update_widgets()

func _apply_settings() -> void:
	(%PlatformSign.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = P.accent_fill()
	$Row/PlatformSign/Number.add_theme_color_override("font_color", P.on_accent())
	%Clock.refresh()
	%Clock.set_text(_time_text(), false)
	%BatteryLabel.add_theme_color_override("font_color", P.text())
	%NetLabel.add_theme_color_override("font_color", P.signal_green())

func _on_timer_timeout() -> void:
	_update_widgets()

func _update_widgets() -> void:
	var time := _time_text()
	if %Clock.text != time:
		%Clock.set_text(time)
	_check_network()
	if DeviceOS.battery_info_path != "":
		_update_battery_async()
	else:
		%BatteryLabel.text = "BAT --"

func _time_text() -> String:
	var now := Time.get_datetime_dict_from_system()
	return P.clock_text(now.hour, now.minute)

func _check_network() -> void:
	var checker := NetworkStatus.new()
	checker.status_checked.connect(func(connected): %NetLabel.visible = connected)
	checker.is_connected_to_network()

func _update_battery_async() -> void:
	# Still reading from the last refresh; it's joined in _show_battery.
	if _battery_thread and _battery_thread.is_started(): return
	_battery_thread = Thread.new()
	_battery_thread.start(_read_battery)

func _read_battery() -> void:
	var capacity = DeviceOS.get_battery_info("capacity")
	var status = DeviceOS.get_battery_info("status")
	call_deferred("_show_battery", capacity, status)

func _show_battery(capacity, status) -> void:
	if _battery_thread.is_started(): _battery_thread.wait_to_finish()
	# The battery script prints nothing when the device has no battery.
	if str(capacity) == "":
		%BatteryLabel.text = "BAT --"
		return
	var charging := str(status).to_lower() == "charging"
	%BatteryLabel.text = ("CHG %s%%" if charging else "BAT %s%%") % str(capacity)
	%BatteryLabel.modulate = Color(1, 0.45, 0.4) if int(capacity) < 20 and not charging else Color.WHITE

func _exit_tree() -> void:
	if _battery_thread and _battery_thread.is_started():
		_battery_thread.wait_to_finish()
