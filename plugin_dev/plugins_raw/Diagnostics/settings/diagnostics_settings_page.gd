extends MarginContainer

## Diagnostics' settings page, linked from Settings via "settings_scene_path"
## in plugin.json. Laid out like the built-in settings pages.

var plugin
var settings

func setup(plugin_arg):
	plugin = plugin_arg
	settings = plugin.settings
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
	_update_toggle(settings.show_overlay, %OverlayEnabled, %OverlayDisabled, %OverlayButton)
	_update_toggle(settings.show_cpu, %CpuEnabled, %CpuDisabled, %CpuButton)
	_update_toggle(settings.show_ram, %RamEnabled, %RamDisabled, %RamButton)
	_update_toggle(settings.show_fps, %FpsEnabled, %FpsDisabled, %FpsButton)
	%PositionLabel.text = settings.corner_name()

func _update_toggle(enabled: bool, enabled_label: Control, disabled_label: Control, button: Button):
	enabled_label.visible = enabled
	disabled_label.visible = not enabled
	button.text = "Disable" if enabled else "Enable"

func _apply():
	settings.save()
	_refresh_ui()

##############################
#           SIGNALS          #
##############################

func _on_overlay_button_pressed() -> void:
	settings.show_overlay = not settings.show_overlay
	_apply()

func _on_cpu_button_pressed() -> void:
	settings.show_cpu = not settings.show_cpu
	_apply()

func _on_ram_button_pressed() -> void:
	settings.show_ram = not settings.show_ram
	_apply()

func _on_fps_button_pressed() -> void:
	settings.show_fps = not settings.show_fps
	_apply()

func _on_position_left_pressed() -> void:
	settings.step_corner(-1)
	_apply()

func _on_position_right_pressed() -> void:
	settings.step_corner(1)
	_apply()

func _on_reset_to_defaults_button_pressed() -> void:
	settings.reset_to_defaults()
	_apply()
