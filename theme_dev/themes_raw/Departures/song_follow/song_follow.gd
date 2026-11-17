extends MarginContainer
## Shown at the foot of other pages while music plays: a slim board row with
## the current flight, plus a reminder of how to get back to it or stop it.

const P = preload("../assets/palette.gd")
const FONT_BOLD = preload("../assets/font_bold.tres")

# [button, what it does] shown as keycaps at the end of the bar.
const HINTS := [["SELECT", "RETURN"], ["START", "STOP"]]

var _cap_style := StyleBoxFlat.new()
var _key_labels: Array[Label] = []

func _ready() -> void:
	_build_hints()
	_apply_settings()
	ThemeManager.theme_settings_updated.connect(_apply_settings)

func _apply_settings() -> void:
	var bar := %Bar.get_theme_stylebox("panel") as StyleBoxFlat
	bar.border_color = P.accent_fill()
	bar.bg_color = Color(P.panel(), 0.96)
	%SongTitle.font_color = P.text()
	%SongTitle.add_theme_color_override("font_color", P.text())
	%SongTitle.queue_redraw()
	(%Tag.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = P.accent_fill()
	$Bar/Row/Tag/Label.add_theme_color_override("font_color", P.on_accent())
	# Keycaps: a raised cap with a heavier lower edge, like a hardware button.
	_cap_style.bg_color = P.button()
	_cap_style.border_color = Color("bdb7aa") if P.light() else Color("3a3f47")
	for key in _key_labels:
		key.add_theme_color_override("font_color", P.text())

func _build_hints() -> void:
	_cap_style.set_border_width_all(1)
	_cap_style.border_width_bottom = 2
	_cap_style.set_corner_radius_all(3)
	_cap_style.content_margin_left = 5
	_cap_style.content_margin_right = 5
	_cap_style.content_margin_top = 0
	_cap_style.content_margin_bottom = 1
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
		key.add_theme_font_override("font", FONT_BOLD)
		key.add_theme_font_size_override("font_size", 10)
		_key_labels.append(key)
		cap.add_child(key)
		%Hints.add_child(cap)
		var action := Label.new()
		action.text = HINTS[i][1]
		action.theme_type_variation = &"DepartureDim"
		action.add_theme_font_size_override("font_size", 10)
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		%Hints.add_child(action)

func setup_display_for(music_record: TagLibMusicRecord) -> void:
	%SongTitle.set_carousel_text("%s  —  %s" % [music_record.title, music_record.artist])
