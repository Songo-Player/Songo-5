extends MarginContainer

var _battery_thread: Thread

var songo_settings = SongoSettings.get_instance()

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
	# Still reading from the last refresh, it gets joined in _update_battery_ui.
	if _battery_thread and _battery_thread.is_started(): return
	_battery_thread = Thread.new()
	_battery_thread.start(_thread_get_battery)
	
func _thread_get_battery():
	var capacity = DeviceOS.get_battery_info('capacity')
	var status = DeviceOS.get_battery_info('status')
	call_deferred("_update_battery_ui", capacity, status)
	
func _update_battery_ui(capacity, status) -> void:
	if _battery_thread.is_started(): _battery_thread.wait_to_finish()
	# The battery script prints nothing when the device has no battery.
	if capacity == "":
		%BatteryPercent.text = "N/A*"
		return
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

func update_time():
	%CurrentOsTimeLabel.text = songo_settings.formatted_time
	
func network_check_display():
	var network_checker = NetworkStatus.new()
	var network_connection_node = %NetworkConnection
	network_checker.status_checked.connect(func(connected):
		%NetworkConnection.visible = connected
		)
	network_checker.is_connected_to_network()

func _exit_tree() -> void:
	if _battery_thread and _battery_thread.is_started():
		_battery_thread.wait_to_finish()
