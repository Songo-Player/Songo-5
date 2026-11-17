extends MarginContainer
## Bottom ticker: the route you took to this page, and the app version.

const P = preload("../assets/palette.gd")

func _ready() -> void:
	%VersionLabel.text = "V" + str(SongoDataResource.VERSION).to_upper().trim_prefix("V")
	_update_route()
	Controller.page_changed.connect(_update_route)
	_apply_settings()
	ThemeManager.theme_settings_updated.connect(_apply_settings)

func _apply_settings() -> void:
	%Arrow.add_theme_color_override("font_color", P.accent_ink())
	var ticker := $Ticker.get_theme_stylebox("panel") as StyleBoxFlat
	ticker.bg_color = P.panel()
	ticker.border_color = P.rule()

func _update_route() -> void:
	%RouteLabel.text = "  ›  ".join(Controller.nav_label).to_upper()
