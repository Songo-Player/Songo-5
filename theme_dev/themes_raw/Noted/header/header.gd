extends MarginContainer
## Top of the page, like the top of a school worksheet: "date: ____" filled
## in by hand on the left; the time, network and a doodled battery on the
## right.

const P = preload("../assets/palette.gd")
const Squiggle = preload("../assets/squiggle.gd")

var _battery_thread: Thread

func _ready() -> void:
	for label in [%DateLabel, %DateValue, %Clock, %BatteryLabel]:
		label.material = Squiggle.material(0.15)
	%NetIcon.material = Squiggle.material(1.5)
	_update_widgets()

func _on_timer_timeout() -> void:
	_update_widgets()

func _update_widgets() -> void:
	var now := Time.get_datetime_dict_from_system()
	%DateValue.text = "%s %d" % [["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"][now.month - 1], now.day]
	%Clock.text = _time_text(now)
	_check_network()
	if DeviceOS.battery_info_path != "":
		_update_battery_async()
	else:
		_show_battery("", "")

func _time_text(now: Dictionary) -> String:
	var hour: int = now.hour
	if SongoSettings.get_instance().clock_24_hour:
		return "%02d:%02d" % [hour, now.minute]
	var suffix := "am" if hour < 12 else "pm"
	hour = hour % 12
	if hour == 0: hour = 12
	return "%d:%02d%s" % [hour, now.minute, suffix]

func _check_network() -> void:
	var checker := NetworkStatus.new()
	checker.status_checked.connect(func(connected): %NetIcon.visible = connected)
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
	if _battery_thread and _battery_thread.is_started(): _battery_thread.wait_to_finish()
	# The battery script prints nothing when the device has no battery.
	if str(capacity) == "":
		%BatteryLabel.text = "??"
		%Battery.level = -1.0
		%Battery.charging = false
		return
	%Battery.charging = str(status).to_lower() == "charging"
	%Battery.level = int(capacity) / 100.0
	%BatteryLabel.text = "%s%%" % str(capacity)

func _exit_tree() -> void:
	if _battery_thread and _battery_thread.is_started():
		_battery_thread.wait_to_finish()
