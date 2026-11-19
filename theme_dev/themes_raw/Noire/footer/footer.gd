extends MarginContainer
## Bottom edge: a strip of film with the scene number (how deep you are),
## the way you came, and the app version as the reel. The film winds on a
## few frames whenever the page changes.

const P = preload("../assets/palette.gd")

var _wind: Tween

func _ready() -> void:
	%VersionLabel.text = "REEL " + str(SongoDataResource.VERSION).to_upper().trim_prefix("V")
	_update_route(false)
	Controller.page_changed.connect(_update_route)
	_apply_settings()
	ThemeManager.theme_settings_updated.connect(_apply_settings)

func _apply_settings() -> void:
	%SceneLabel.add_theme_color_override("font_color", P.accent_ink())

func _update_route(wind := true) -> void:
	var route: Array = Controller.nav_label
	%SceneLabel.text = "SC. %d" % maxi(route.size(), 1)
	%RouteLabel.text = " / ".join(route).to_upper()
	if not wind: return
	if _wind: _wind.kill()
	_wind = create_tween()
	_wind.tween_property(%Strip, "offset", %Strip.offset + 36.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
