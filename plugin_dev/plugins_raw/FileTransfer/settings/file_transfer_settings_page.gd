extends MarginContainer

## File Transfer's settings page, linked from Settings via "settings_scene_path"
## in plugin.json. Laid out like the built-in settings pages.

const COLOR_ON := Color(0, 0.913725, 0, 1)
const COLOR_OFF := Color(0.870588, 0, 0, 1)
const MAX_ADDRESSES := 2

var plugin
var settings

func setup(plugin_arg):
	plugin = plugin_arg
	settings = plugin.settings
	plugin.state_changed.connect(_refresh_ui)
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
	var running: bool = plugin.is_running()
	%ServerStatus.text = "Receiving" if plugin.is_receiving() else ("Running" if running else "Stopped")
	%ServerStatus.add_theme_color_override("font_color", COLOR_ON if running else COLOR_OFF)
	%ServerButton.text = "Stop" if running else "Start"
	%AddressLabel.text = _address_text(running)
	%PinLabel.visible = running and settings.require_pin
	if running: %PinLabel.text = "PIN: %s" % plugin.server.get_pin()
	%ReceivedLabel.visible = running and plugin.files_received > 0
	%ReceivedLabel.text = "%d file%s received, last: %s" % [plugin.files_received, "" if plugin.files_received == 1 else "s", plugin.last_file]
	var directory: String = plugin.music_directory()
	%DirectoryLabel.text = directory if directory != "" else "No music directories, add one in Data and Storage"
	%PortLabel.text = str(settings.port)
	_update_toggle(settings.require_pin, %RequirePinEnabled, %RequirePinDisabled, %RequirePinButton)

func _address_text(running: bool) -> String:
	if not running: return "Start the server, then open the address shown here in a web browser on the same network."
	var urls := PackedStringArray()
	for address in plugin.addresses().slice(0, MAX_ADDRESSES):
		urls.append("http://%s:%d" % [address, settings.port])
	return "\nor ".join(urls) if not urls.is_empty() else "Not connected to a network"

func _update_toggle(enabled: bool, enabled_label: Control, disabled_label: Control, button: Button):
	enabled_label.visible = enabled
	disabled_label.visible = not enabled
	button.text = "Disable" if enabled else "Enable"

func _apply():
	settings.save()
	_refresh_ui()

# Where and how the server runs is fixed while it's running.
func _can_change() -> bool:
	if plugin.is_running():
		UiHelper.flash_message("Stop the server to change this")
		return false
	return true

##############################
#           SIGNALS          #
##############################

func _on_server_button_pressed() -> void:
	if plugin.is_running():
		plugin.stop_server()
	else:
		var error: String = plugin.start_server()
		if error != "": UiHelper.flash_message(error)
	_refresh_ui()

func _step_directory(direction: int) -> void:
	if not _can_change(): return
	plugin.step_music_directory(direction)
	_apply()

func _on_directory_left_pressed() -> void:
	_step_directory(-1)

func _on_directory_right_pressed() -> void:
	_step_directory(1)

func _step_port(direction: int) -> void:
	if not _can_change(): return
	settings.step_port(direction)
	_apply()

func _on_port_left_pressed() -> void:
	_step_port(-1)

func _on_port_right_pressed() -> void:
	_step_port(1)

func _on_require_pin_button_pressed() -> void:
	if not _can_change(): return
	settings.require_pin = not settings.require_pin
	_apply()

func _on_reset_to_defaults_button_pressed() -> void:
	if not _can_change(): return
	settings.reset_to_defaults()
	_apply()
