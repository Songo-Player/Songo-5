extends HBoxContainer

## A downloaded theme in the Downloaded Themes list, laid out like the
## playlists in Data and Storage: its name, version, and a Delete button.

signal deleted

var plugin
var theme_id := ""

func setup(plugin_arg, theme_id_arg: String) -> void:
	plugin = plugin_arg
	theme_id = theme_id_arg
	var info: Dictionary = ThemeManager.parse_theme_json(plugin.theme_dir(theme_id))
	$CarouselLabel.set_carousel_text(str(info.get("name", theme_id)))
	var version := str(info.get("version", ""))
	$Version.text = "v" + version
	$Version.visible = version != ""

func _on_button_pressed() -> void:
	# Deleting the theme in use leaves this page for the main menu, so there's
	# no list left to update.
	var was_active: bool = plugin.is_active(theme_id)
	if plugin.delete(theme_id) and not was_active: deleted.emit()
