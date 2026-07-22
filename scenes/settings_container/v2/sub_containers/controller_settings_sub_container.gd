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
	update_start_behavior_ui()

func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.nav_back()
	
func update_ab_layout_ui():
	if songo_settings.ab_layout_swapped:
		%ABLayoutLabel.text = "Swapped"
	else:
		%ABLayoutLabel.text = "Default"
		
func update_start_behavior_ui():
	var keys = SongoSettings.START_BEHAVIOR.keys()
	var text = keys[songo_settings.start_btn_behavior]
	%StartBehaviorLabel.text = text
	
func update_seek_forward_ui():
	%SeekForwardTimerLabel.text = "%ss" % songo_settings.seek_forward_time
		
func update_seek_backward_ui():
	%SeekBackwardTimerLabel.text = "%ss" % songo_settings.seek_backward_time
		
func update_xy_layout_ui():
	if songo_settings.xy_layout_swapped:
		%XYLayoutLabel.text = "Swapped"
	else:
		%XYLayoutLabel.text = "Default"


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



func _on_reset_to_defaults_button_pressed() -> void:
	songo_settings.ab_layout_swapped = false
	songo_settings.xy_layout_swapped = false
	songo_settings.seek_backward_time_index = 1
	songo_settings.seek_forward_time_index = 1
	songo_settings.start_btn_behavior = SongoSettings.START_BEHAVIOR.LOCK
	songo_settings.save()
	_ui_settings_refresh()
	


func _on_start_behavior_button_pressed() -> void:
	var new_val = songo_settings.start_btn_behavior + 1
	if new_val >= SongoSettings.START_BEHAVIOR.size():
		new_val = 0
	DeviceOS.keep_screen_awake = false
	songo_settings.start_btn_behavior = new_val
	songo_settings.save()
	update_start_behavior_ui()
