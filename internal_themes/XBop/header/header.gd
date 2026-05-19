extends MarginContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update_widgets()

func _on_timer_timeout() -> void:
	_update_widgets()
	
func _update_widgets():
	update_time()
	network_check_display()
	if DeviceOS.battery_info_path != "":
		update_battery_async()
	else:
		%BatteryPercent.text = "N/A*"
		
func update_battery_async() -> void:
	var thread := Thread.new()
	thread.start(Callable(self, "_thread_get_battery"))
	
func _thread_get_battery():
	var capacity = DeviceOS.get_battery_info('capacity')
	var status = DeviceOS.get_battery_info('status')
	call_deferred("_update_battery_ui", capacity, status)
	
func _update_battery_ui(capacity, status) -> void:
	%BatteryPercent.text = str(capacity)+"%"
	if int(capacity) >= 90: 
		%BatteryIcon.texture = preload("res://assets/battery-full.svg")
	elif int(capacity) >= 70:
		%BatteryIcon.texture = preload("res://assets/battery-threequarters.svg")
	elif int(capacity) >= 45:
		%BatteryIcon.texture = preload("res://assets/battery-half.svg")
	elif int(capacity) >= 20:
		%BatteryIcon.texture = preload("res://assets/battery-quarter.svg")
	else:
		%BatteryIcon.texture = preload("res://assets/battery.svg")
	
	#if status.to_lower() == "charging":

func get_time_string() -> String:
	var now = Time.get_datetime_dict_from_system()
	var hour_12 = now.hour % 12
	if hour_12 == 0: hour_12 = 12
	var hour = str(hour_12)
	if ThemeManager.settings["clock_24_hour"]: hour = now.hour
	var minute = str(now.minute).pad_zeros(2)
	return "%s:%s" % [hour, minute]

func update_time():
	%CurrentOsTimeLabel.text = get_time_string()
	
func network_check_display():
	var network_checker = NetworkStatus.new()
	var network_connection_node = %NetworkConnection
	network_checker.status_checked.connect(func(connected):
		if connected: %NetworkConnection.show()
		)
	network_checker.is_connected_to_network()
