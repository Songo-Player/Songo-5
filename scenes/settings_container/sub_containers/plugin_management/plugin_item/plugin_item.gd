extends PanelContainer

## One plugin's row in Plugin Management: its name, status and plugin.json
## details, with Settings / Enable-Disable / Delete buttons.

signal deleted

const STATUS_COLORS := {
	"good": Color(0, 0.913725, 0, 1),
	"off": Color(0.75, 0.75, 0.75, 1),
	"notice": Color(1, 0.76, 0.2, 1),
	"bad": Color(0.870588, 0, 0, 1),
}

var plugin_name := ""
# Delete asks for a second press before it removes anything.
var _confirming_delete := false

func setup(plugin_name_arg: String) -> void:
	plugin_name = plugin_name_arg
	var info: Dictionary = _entry().info
	%NameLabel.text = plugin_name
	var details := []
	if str(info.get("version", "")) != "": details.append("v%s" % info["version"])
	if str(info.get("author", "")) != "": details.append("by %s" % info["author"])
	%DetailsLabel.text = " ".join(details)
	%DetailsLabel.visible = not details.is_empty()
	%DescriptionLabel.text = str(info.get("description", ""))
	%DescriptionLabel.visible = %DescriptionLabel.text != ""

	%SettingsButton.pressed.connect(_on_settings_pressed)
	%ToggleButton.pressed.connect(_on_toggle_pressed)
	%DeleteButton.pressed.connect(_on_delete_pressed)
	%DeleteButton.focus_exited.connect(_reset_delete)
	_refresh()

func buttons() -> Array:
	return [%SettingsButton, %ToggleButton, %DeleteButton]

## First button that can be used, for the page to focus.
func first_button() -> Button:
	for button in [%SettingsButton, %ToggleButton, %DeleteButton]:
		if not button.disabled: return button
	return %SettingsButton

func _entry() -> Dictionary:
	return PluginManager.discovered.get(plugin_name, {})

func _refresh() -> void:
	var entry := _entry()
	var enabled: bool = PluginManager.is_enabled(plugin_name)
	var loaded: bool = entry.instance != null

	if loaded and enabled: _set_status("Enabled", "good")
	elif loaded: _set_status("Disabled · Restart to apply", "notice")
	elif enabled and entry.enabled_at_boot: _set_status("Failed to load", "bad")
	elif enabled: _set_status("Enabled · Restart to apply", "notice")
	else: _set_status("Disabled", "off")

	%ToggleButton.text = "Disable" if enabled else "Enable"
	# Its page needs the running plugin, so it isn't available until it's loaded.
	%SettingsButton.disabled = not loaded or entry.settings_scene == ""
	%DeleteButton.disabled = not PluginManager.can_delete(plugin_name)
	_reset_delete()

func _set_status(text: String, kind: String) -> void:
	%StatusLabel.text = text
	%StatusLabel.add_theme_color_override("font_color", STATUS_COLORS[kind])

func _reset_delete() -> void:
	_confirming_delete = false
	%DeleteButton.text = "Delete"

func _on_settings_pressed() -> void:
	var entry := _entry()
	if entry.instance == null or entry.settings_scene == "": return
	Controller.plugin_settings(entry.instance, entry.settings_scene)

func _on_toggle_pressed() -> void:
	var enabling: bool = not PluginManager.is_enabled(plugin_name)
	PluginManager.set_enabled(plugin_name, enabling)
	_refresh()
	if PluginManager.needs_restart(plugin_name):
		UiHelper.flash_message("Restart Songo#5 to finish %s %s" % ["enabling" if enabling else "disabling", plugin_name])

func _on_delete_pressed() -> void:
	if not _confirming_delete:
		_confirming_delete = true
		%DeleteButton.text = "Confirm"
		return
	var was_loaded: bool = _entry().instance != null
	var error := PluginManager.delete_plugin(plugin_name)
	if error != "":
		UiHelper.flash_message(error)
		_reset_delete()
		return
	if was_loaded: UiHelper.flash_message("%s deleted. Restart Songo#5 to finish removing it" % plugin_name)
	else: UiHelper.flash_message("%s deleted" % plugin_name)
	deleted.emit()
