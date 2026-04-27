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
	update_ab_layout_ui()
	update_xy_layout_ui()
	update_seek_forward_ui()
	update_seek_backward_ui()
	update_lock_input_sleep_ui()
		
func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.new_nav_back()
	
func update_ab_layout_ui():
	if songo_settings.ab_layout_swapped:
		%ABLayoutLabel.text = "Swapped"
	else:
		%ABLayoutLabel.text = "Default"
		
func update_seek_forward_ui():
	%SeekForwardTimerLabel.text = "%ss" % songo_settings.seek_forward_time
		
func update_seek_backward_ui():
	%SeekBackwardTimerLabel.text = "%ss" % songo_settings.seek_backward_time
		
func update_xy_layout_ui():
	if songo_settings.xy_layout_swapped:
		%XYLayoutLabel.text = "Swapped"
	else:
		%XYLayoutLabel.text = "Default"

func update_lock_input_sleep_ui():
	if songo_settings.lock_inputs_on_sleep:
		%LockInputsSleepDisabled.hide()
		%LockInputsSleepEnabled.show()
		%LockInputsSleepSettingToggleButton.text = "Disable"
	else:
		%LockInputsSleepDisabled.show()
		%LockInputsSleepEnabled.hide()
		%LockInputsSleepSettingToggleButton.text = "Enable"

func _on_tree_entered() -> void:
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

func _on_tree_exiting() -> void:
	get_viewport().gui_focus_changed.disconnect(_on_focus_changed)

func _on_focus_changed(item: Control):
	if item == %ABLayoutButton:
		%ScrollContainer.scroll_vertical = 0
	if item == %ResetToDefaultsButton:
		%ScrollContainer.scroll_vertical = 999


func _on_ab_layout_button_pressed() -> void:
	songo_settings.ab_layout_swapped = !songo_settings.ab_layout_swapped
	songo_settings.save()
	DeviceOS.swap_input_actions("back", "ui_accept")
	update_ab_layout_ui()

func _on_xy_layout_button_pressed() -> void:
	songo_settings.xy_layout_swapped = !songo_settings.xy_layout_swapped
	songo_settings.save()
	DeviceOS.swap_input_actions("x", "Y")
	update_xy_layout_ui()


func _on_seek_forward_timer_down_pressed() -> void:
	songo_settings.seek_forward_time_index -= 1
	if songo_settings.seek_forward_time_index < 0:
		songo_settings.seek_forward_time_index = 4
	songo_settings.save()
	update_seek_forward_ui()


func _on_seek_forward_timer_up_pressed() -> void:
	songo_settings.seek_forward_time_index += 1
	if songo_settings.seek_forward_time_index > 4:
		songo_settings.seek_forward_time_index = 0
	songo_settings.save()
	update_seek_forward_ui()


func _on_seek_backward_timer_down_pressed() -> void:
	songo_settings.seek_backward_time_index -= 1
	if songo_settings.seek_backward_time_index < 0:
		songo_settings.seek_backward_time_index = 4
	songo_settings.save()
	update_seek_backward_ui()


func _on_seek_backward_timer_up_pressed() -> void:
	songo_settings.seek_backward_time_index += 1
	if songo_settings.seek_backward_time_index > 4:
		songo_settings.seek_backward_time_index = 0
	songo_settings.save()
	update_seek_backward_ui()


func _on_lock_inputs_sleep_setting_toggle_button_pressed() -> void:
	songo_settings.lock_inputs_on_sleep= !songo_settings.lock_inputs_on_sleep
	songo_settings.save()
	update_lock_input_sleep_ui()


func _on_reset_to_defaults_button_pressed() -> void:
	songo_settings.lock_inputs_on_sleep = false
	songo_settings.ab_layout_swapped = false
	songo_settings.xy_layout_swapped = false
	songo_settings.seek_backward_time_index = 1
	songo_settings.seek_forward_time_index = 1
	songo_settings.save()
	_ui_settings_refresh()
	
