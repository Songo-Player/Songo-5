extends MarginContainer

## Dev tool for mapping a device's controls. With songo.conf's dev_ctrl_remap
## set to true, songo_app opens this over the main menu at launch, and it has
## you press a button for each remappable action in turn, capturing presses as
## Set does in Controller Settings. Pressing a button that's already mapped to
## another action aborts with nothing changed (dev_ctrl_remap stays true, so it
## comes back on the next launch). Once every action has a button they're saved
## to Songo's controller settings and written to songo.conf's ctrl_* keys, and
## dev_ctrl_remap is set back to false.
##     load(DEV_CTRL_REMAP).new().open()

const CONF_KEY = "dev_ctrl_remap"
# Margin around the card at 4:3; wider screens add to the sides (as the info panel)
const CARD_MARGIN := 50
# Each remappable action (SongoSettings.ACTION_BINDINGS), in the order asked
# for, with its name on screen
const STEPS = [
	["ui_accept", "Accept"],
	["back", "Back"],
	["x", "Shuffle"],
	["Y", "Quick Menu"],
	["L1", "L1"],
	["R1", "R1"],
	["L2", "L2"],
	["R2", "R2"],
	["start", "Start"],
	["select", "Select"],
]

# The button captured for each step so far
var _bindings: Array[InputEvent] = []
# The last captured input, ignored until it's released: a held trigger keeps
# sending presses, which would otherwise land on the next action too
var _held: InputEvent = null
var _open := false
var _step_label: Label
var _action_label: Label

func open() -> void:
	_build_ui()
	_open = true
	UiHelper.open_overlay_panel(self)
	resized.connect(_cap_card_width)
	_cap_card_width()
	# Keep the main menu's focused button from being pressed underneath
	UiHelper.overlay_window.grab_focus()
	_show_step()

func close() -> void:
	if not _open: return
	_open = false
	UiHelper.close_overlay_panel(self)

func _input(event: InputEvent) -> void:
	if not _open: return
	var is_trigger: bool = event is InputEventJoypadMotion and event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]
	if not (event is InputEventJoypadButton or event is InputEventKey or is_trigger): return
	# Nothing reaches the menu underneath while mapping
	get_viewport().set_input_as_handled()
	var binding := _binding_for(event)
	if binding == null: return
	if _held != null and _held.is_match(binding):
		# For triggers, not pressed means let back past the halfway point
		if not event.is_pressed(): _held = null
		return
	if not event.is_pressed() or event.is_echo(): return

	for i in range(_bindings.size()):
		if _bindings[i].is_match(binding):
			_abort(STEPS[_step()][1], STEPS[i][1], binding)
			return
	_bindings.append(binding)
	_held = binding
	if _step() == STEPS.size(): _finish()
	else: _show_step()

func _step() -> int:
	return _bindings.size()

# The binding to store for a press, as Controller Settings stores it, or null
# for the d-pad and arrow keys, which drive navigation and can't be mapped
func _binding_for(event: InputEvent) -> InputEvent:
	if event is InputEventJoypadButton:
		if event.button_index >= JOY_BUTTON_DPAD_UP and event.button_index <= JOY_BUTTON_DPAD_RIGHT:
			return null
		# What the button would be unrotated; apply_action_bindings rotates it back
		return SongoSettings.joy_binding(DeviceOS.unrotate_joy_button(event.button_index) as JoyButton)
	if event is InputEventJoypadMotion:
		return SongoSettings.axis_binding(event.axis)
	if event.physical_keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		return null
	return SongoSettings.key_binding(event.keycode, event.physical_keycode)

func _abort(action_name: String, used_by: String, binding: InputEvent) -> void:
	UiHelper.flash_message("Control mapping cancelled: %s is already mapped to %s. Nothing was changed." % [SongoSettings.binding_name(binding), used_by], 5.0)
	print("dev_ctrl_remap: aborted at %s, %s is already %s" % [action_name, SongoSettings.binding_name(binding), used_by])
	close()

func _finish() -> void:
	var settings := SongoSettings.get_instance()
	var conf := {}
	for i in range(STEPS.size()):
		var property: String = SongoSettings.ACTION_BINDINGS[STEPS[i][0]]
		settings.set(property, _bindings[i])
		conf[SongoSettings.BINDING_CONF_KEYS[property]] = SongoSettings.binding_name(_bindings[i])
	settings.save()
	DeviceOS.apply_action_bindings()
	conf[CONF_KEY] = "false"
	var err := SongoConf.set_values(conf)
	if err == OK:
		UiHelper.flash_message("Controls mapped, and saved to songo.conf", 5.0)
	else:
		UiHelper.flash_message("Controls mapped, but songo.conf couldn't be updated (%s)" % error_string(err), 5.0)
	print("dev_ctrl_remap: mapped %s (songo.conf: %s)" % [conf, error_string(err)])
	close()

func _show_step() -> void:
	_step_label.text = "%d of %d" % [_step() + 1, STEPS.size()]
	_action_label.text = "Press the button for %s" % STEPS[_step()][1]

func _cap_card_width() -> void:
	var side := UiHelper.capped_card_side_margin(size, CARD_MARGIN)
	$MarginContainer.add_theme_constant_override("margin_left", side)
	$MarginContainer.add_theme_constant_override("margin_right", side)

# Built here rather than as a scene: it's a dev tool, laid out like the info panel
func _build_ui() -> void:
	name = "DevCtrlRemap"
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 1
	z_as_relative = false
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, CARD_MARGIN)
	add_child(margin)

	var panel := PanelContainer.new()
	panel.theme = load("res://assets/songo_base_theme.tres")
	panel.theme_type_variation = &"SongoPanel"
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	box.add_child(_label("Map Controls"))
	_step_label = _label("")
	box.add_child(_step_label)
	_action_label = _label("")
	_action_label.add_theme_font_size_override("font_size", 28)
	box.add_child(_action_label)
	box.add_child(_label("Give each action its own button. Pressing one that's already used cancels mapping."))

func _label(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"SongoSettingsLabel"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
