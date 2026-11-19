extends PanelContainer
## The room behind every page (see atmosphere.gdshader). Also repaints the
## shared Theme in the chosen accent whenever settings change, so the app's
## own pages (Settings and the like) pick up the spot color too.

const P = preload("../assets/palette.gd")
const SILVER = preload("../assets/silver_print.tres")

func _ready() -> void:
	%Room.resized.connect(_on_room_resized)
	_on_room_resized()
	_apply_settings()
	ThemeManager.theme_settings_updated.connect(_apply_settings)

func _on_room_resized() -> void:
	(%Room.material as ShaderMaterial).set_shader_parameter("rect_size", %Room.size)

func _apply_settings() -> void:
	var room: ShaderMaterial = %Room.material
	room.set_shader_parameter("light_color", P.blind_light())
	room.set_shader_parameter("rain_amount", 1.0 if P.rain() else 0.0)
	room.set_shader_parameter("grain_amount", 0.05 if P.film_grain() else 0.0)
	# Every cover in the theme shares this one material.
	SILVER.set_shader_parameter("amount", 1.0 if P.monochrome_art() else 0.0)

	var t := get_tree().root.theme
	if t == null: return
	var accent := P.accent()
	_fill(t, "Button", "focus", accent)
	_fill(t, "Button", "pressed", accent)
	for name in ["font_focus_color", "font_pressed_color", "font_hover_pressed_color", "icon_focus_color", "icon_pressed_color"]:
		t.set_color(name, "Button", P.on_accent())
	_border(t, "ListButton", "focus", accent)
	_border(t, "VScrollBar", "scroll_focus", accent)
	_fill(t, "VScrollBar", "grabber_highlight", accent)
	_fill(t, "VScrollBar", "grabber_pressed", accent)

func _fill(t: Theme, type: String, style_name: String, color: Color) -> void:
	var style := t.get_stylebox(style_name, type) as StyleBoxFlat
	if style: style.bg_color = color

func _border(t: Theme, type: String, style_name: String, color: Color) -> void:
	var style := t.get_stylebox(style_name, type) as StyleBoxFlat
	if style: style.border_color = color
