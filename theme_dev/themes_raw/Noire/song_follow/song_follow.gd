extends MarginContainer
## Shown at the top of other pages while music plays: a marquee strip with
## what's showing, and how to get back to it or stop it.

const P = preload("../assets/palette.gd")

# [button, what it does] shown as keycaps at the end of the bar.
const HINTS := [["SELECT", "RETURN"], ["START", "STOP"]]

var _cap_style := StyleBoxFlat.new()

func _ready() -> void:
	_build_hints()
	_apply_settings()
	ThemeManager.theme_settings_updated.connect(_apply_settings)

func _apply_settings() -> void:
	(%Bar.get_theme_stylebox("panel") as StyleBoxFlat).border_color = P.accent()
	(%Tag.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = P.accent()
	%TagLabel.add_theme_color_override("font_color", P.on_accent())

func _build_hints() -> void:
	_cap_style.bg_color = P.CARD
	_cap_style.border_color = Color("4a4945")
	_cap_style.set_border_width_all(1)
	_cap_style.content_margin_left = 5
	_cap_style.content_margin_right = 5
	_cap_style.content_margin_top = 0
	_cap_style.content_margin_bottom = 0
	for i in HINTS.size():
		if i > 0:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(4, 0)
			%Hints.add_child(spacer)
		var cap := PanelContainer.new()
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.add_theme_stylebox_override("panel", _cap_style)
		var key := Label.new()
		key.text = HINTS[i][0]
		key.add_theme_font_size_override("font_size", 10)
		key.add_theme_color_override("font_color", P.TEXT)
		cap.add_child(key)
		%Hints.add_child(cap)
		var action := Label.new()
		action.text = HINTS[i][1]
		action.theme_type_variation = &"NoireDim"
		action.add_theme_font_size_override("font_size", 10)
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		%Hints.add_child(action)

func setup_display_for(music_record: TagLibMusicRecord) -> void:
	%SongTitle.set_carousel_text("%s  —  %s" % [music_record.title, music_record.artist])
