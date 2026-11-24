extends SongoPlugin

## Shows Songo's CPU, RAM and FPS in a small overlay over every page. What it
## shows, and where, is set from the plugin's page in Settings.

const DiagnosticsSettings = preload("settings/diagnostics_settings.gd")
const DiagnosticsOverlay = preload("diagnostics_overlay.gd")

var settings = _load_settings()
var overlay: Control

func _plugin_ready() -> void:
	overlay = DiagnosticsOverlay.new()
	overlay.settings = settings
	# Inside the main UI's TransformContainer rather than a CanvasLayer of its
	# own, so it follows the display rotation and UI scale like everything else.
	var screen: Control = UiHelper.transform_container
	if screen == null:
		push_error("Diagnostics: no main UI to show the overlay in")
		return
	screen.add_child(overlay)

# Saved settings, or fresh defaults if there's no usable save.
func _load_settings():
	if ResourceLoader.exists(DiagnosticsSettings.SAVE_PATH):
		var saved = ResourceLoader.load(DiagnosticsSettings.SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if saved != null && saved.get_script() == DiagnosticsSettings: return saved
	return DiagnosticsSettings.new()
