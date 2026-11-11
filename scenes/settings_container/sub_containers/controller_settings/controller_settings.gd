extends MarginContainer

var songo_settings = SongoSettings.get_instance()

# Action waiting for a button press after "Set", empty when not listening
var listening_action := ""
# Frame a button was captured on, so that press doesn't also run handle_input
var captured_frame := -1

# Remappable action -> [binding label, Set button]. A function rather than an
# @onready var since setup() runs before the node is ready.
func _binding_rows() -> Dictionary:
	return {
		"ui_accept": [%ConfirmButtonLabel, %ConfirmSetButton],
		"back": [%BackButtonLabel, %BackSetButton],
		"x": [%ShuffleButtonLabel, %ShuffleSetButton],
		"Y": [%QuickMenuButtonLabel, %QuickMenuSetButton],
		"L1": [%L1ButtonLabel, %L1SetButton],
		"R1": [%R1ButtonLabel, %R1SetButton],
		"L2": [%L2ButtonLabel, %L2SetButton],
		"R2": [%R2ButtonLabel, %R2SetButton],
		"start": [%StartButtonLabel, %StartSetButton],
		"select": [%SelectButtonLabel, %SelectSetButton],
	}

func setup():
	_ui_settings_refresh()
	
func _ready():
	await get_tree().process_frame
	%PageLabel.grab_focus()
	%ScrollContainer.scroll_vertical = 0

func render_ui():
	pass
	
func _ui_settings_refresh():
	update_button_mapping_ui()
	update_seek_forward_ui()
	update_seek_backward_ui()
	update_start_behavior_ui()
	update_stick_nav_ui()

func handle_input(delta: float):
	if listening_action != "" || captured_frame == Engine.get_process_frames():
		return
	if Input.is_action_just_pressed("back"):
		Controller.nav_back()
	
func update_button_mapping_ui():
	%MappingsDisplayLabel.text = "Custom" if songo_settings.has_custom_bindings() else "Default"
	var rows := _binding_rows()
	for action in rows:
		var label: CarouselLabel = rows[action][0]
		var set_button: Button = rows[action][1]
		if action == listening_action:
			label.set_carousel_text("Press a button...")
			set_button.text = "Cancel"
		else:
			label.set_carousel_text(SongoSettings.binding_name(songo_settings.get(SongoSettings.ACTION_BINDINGS[action])))
			set_button.text = "Set"

func update_start_behavior_ui():
	var keys = SongoSettings.START_BEHAVIOR.keys()
	var text = keys[songo_settings.start_btn_behavior]
	%StartBehaviorLabel.text = text
	
func update_seek_forward_ui():
	%SeekForwardTimerLabel.text = "%ss" % songo_settings.seek_forward_time
		
func update_seek_backward_ui():
	%SeekBackwardTimerLabel.text = "%ss" % songo_settings.seek_backward_time
	
func update_stick_nav_ui():
	if songo_settings.enable_stick_nav:
		%StickNavEnabled.show()
		%StickNavDisabled.hide()
		%StickNavButton.text = "Disable"
	else:
		%StickNavEnabled.hide()
		%StickNavDisabled.show()
		%StickNavButton.text = "Enable"


func _on_tree_entered() -> void:
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

func _on_tree_exiting() -> void:
	get_viewport().gui_focus_changed.disconnect(_on_focus_changed)
	listening_action = ""

func _on_focus_changed(item: Control):
	if item == %MappingsButton:
		%ScrollContainer.scroll_vertical = 0
	if item == %ResetToDefaultsButton:
		%ScrollContainer.scroll_vertical = 999


func _on_mappings_button_pressed() -> void:
	%MappingsPickerContainer.visible = not %MappingsPickerContainer.visible
	if %MappingsPickerContainer.visible: %MappingsButton.text = "Hide"
	else:
		%MappingsButton.text = "Change"
		listening_action = ""
		update_button_mapping_ui()

func _on_confirm_set_button_pressed() -> void:
	_toggle_listening("ui_accept")

func _on_back_set_button_pressed() -> void:
	_toggle_listening("back")

func _on_shuffle_set_button_pressed() -> void:
	_toggle_listening("x")

func _on_quick_menu_set_button_pressed() -> void:
	_toggle_listening("Y")

func _on_l1_set_button_pressed() -> void:
	_toggle_listening("L1")

func _on_r1_set_button_pressed() -> void:
	_toggle_listening("R1")

func _on_l2_set_button_pressed() -> void:
	_toggle_listening("L2")

func _on_r2_set_button_pressed() -> void:
	_toggle_listening("R2")

func _on_start_set_button_pressed() -> void:
	_toggle_listening("start")

func _on_select_set_button_pressed() -> void:
	_toggle_listening("select")

func _toggle_listening(action: String) -> void:
	# Pressing Set again (only reachable by touch/mouse while listening) cancels
	listening_action = "" if listening_action == action else action
	update_button_mapping_ui()

func _input(event: InputEvent) -> void:
	if listening_action == "": return
	var is_trigger = event is InputEventJoypadMotion && event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]
	if not (event is InputEventJoypadButton or event is InputEventKey or is_trigger): return
	# For triggers this means pulled past the halfway point
	if not event.is_pressed() or event.is_echo(): return
	# Swallow the press so it doesn't also navigate or click the focused button
	get_viewport().set_input_as_handled()
	var binding: InputEvent
	if event is InputEventJoypadButton:
		# The d-pad drives navigation, don't let it be rebound
		if event.button_index >= JOY_BUTTON_DPAD_UP && event.button_index <= JOY_BUTTON_DPAD_RIGHT:
			return
		binding = SongoSettings.joy_binding(event.button_index)
	elif is_trigger:
		binding = SongoSettings.axis_binding(event.axis)
	else:
		# Same for the arrow keys
		if event.physical_keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			return
		binding = SongoSettings.key_binding(event.keycode, event.physical_keycode)
	_set_action_binding(listening_action, binding)
	listening_action = ""
	captured_frame = Engine.get_process_frames()
	update_button_mapping_ui()

func _set_action_binding(action: String, binding: InputEvent) -> void:
	var property: String = SongoSettings.ACTION_BINDINGS[action]
	# Binding an input another action already uses swaps the two
	for other_property in SongoSettings.ACTION_BINDINGS.values():
		if other_property != property && songo_settings.get(other_property).is_match(binding):
			songo_settings.set(other_property, songo_settings.get(property))
	songo_settings.set(property, binding)
	songo_settings.save()
	DeviceOS.apply_action_bindings()


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


func _on_stick_nav_button_pressed() -> void:
	songo_settings.enable_stick_nav = !songo_settings.enable_stick_nav
	songo_settings.save()
	update_stick_nav_ui()


func _on_reset_to_defaults_button_pressed() -> void:
	songo_settings.reset_action_bindings()
	listening_action = ""
	DeviceOS.apply_action_bindings()
	songo_settings.seek_backward_time_index = 1
	songo_settings.seek_forward_time_index = 1
	songo_settings.start_btn_behavior = SongoSettings.START_BEHAVIOR.LOCK
	songo_settings.enable_stick_nav = false
	songo_settings.save()
	_ui_settings_refresh()
	


func _on_start_behavior_left_pressed() -> void:
	_step_start_behavior(-1)

func _on_start_behavior_right_pressed() -> void:
	_step_start_behavior(1)

func _step_start_behavior(step: int) -> void:
	var new_val = wrapi(songo_settings.start_btn_behavior + step, 0, SongoSettings.START_BEHAVIOR.size())
	DeviceOS.keep_screen_awake = false
	songo_settings.start_btn_behavior = new_val
	songo_settings.save()
	update_start_behavior_ui()
