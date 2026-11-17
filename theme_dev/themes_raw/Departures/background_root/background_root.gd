extends PanelContainer
## The station behind every page. Also repaints the shared Theme for the
## current board color and light/dark mode whenever the settings change, so
## every page (including the app's own, like Settings) follows along.

const P = preload("../assets/palette.gd")

# A collection page's Shuffle Play row copies the list text color into these
# nodes' modulate only when it gains or loses focus, so after a color change
# they keep the old color until focus moves. They're re-synced here.
const SHUFFLE_PARTS := ["ShuffleIcon", "ShuffleText1", "ShuffleText2"]

func _ready() -> void:
	_apply_settings()
	ThemeManager.theme_settings_updated.connect(_apply_settings)
	get_tree().node_added.connect(_on_node_added)

func _apply_settings() -> void:
	var board := P.board()
	var light := P.light()
	(get_theme_stylebox("panel") as StyleBoxFlat).bg_color = P.surface()
	var housing: ShaderMaterial = %Housing.material
	housing.set_shader_parameter("base_color", P.surface())
	housing.set_shader_parameter("glow_color", board)
	# Daylight has no board glow and barely any shadow; at night the
	# lettering lights the housing and the corners fall away.
	housing.set_shader_parameter("slat_strength", 0.03 if light else 0.35)
	housing.set_shader_parameter("vignette_strength", 0.05 if light else 0.45)
	housing.set_shader_parameter("glow_strength", 0.0 if light else 0.06)

	# Deferred so every component has recolored its own panels first.
	if light: _fix_labels_on_dark_panels.call_deferred(get_tree().root)
	for part in get_tree().root.find_children("Shuffle*", "", true, false):
		if str(part.name) in SHUFFLE_PARTS: _sync_shuffle_row.call_deferred(part)

	var t := get_tree().root.theme
	if t == null: return

	# Text on the page
	t.set_color("font_color", "Label", P.text())
	t.set_color("font_color", "DepartureDim", P.text_dim())

	# Buttons: page colored when idle, board colored when focused or pressed
	for name in ["font_color", "font_hover_color"]:
		t.set_color(name, "Button", P.text())
	_fill(t, "Button", "normal", P.button())
	_fill(t, "Button", "hover", P.button_hover())
	_fill(t, "Button", "focus", P.accent_fill())
	_fill(t, "Button", "pressed", P.accent_fill())
	for name in ["font_focus_color", "font_pressed_color", "font_hover_pressed_color", "icon_focus_color", "icon_pressed_color"]:
		t.set_color(name, "Button", P.on_accent())
	for style_name in ["normal", "hover"]:
		var style := t.get_stylebox(style_name, "Button") as StyleBoxFlat
		if style: style.border_color = P.rule() if light else P.BOARD_BG

	# List rows: a rule under each, a lit row with a board-colored edge on focus
	t.set_color("font_color", "ListButton", P.text())
	t.set_color("font_hover_color", "ListButton", P.text())
	t.set_color("icon_hover_color", "ListButton", P.text())
	t.set_color("icon_normal_color", "ListButton", P.text())
	for name in ["font_focus_color", "font_pressed_color", "font_hover_pressed_color", "icon_focus_color"]:
		t.set_color(name, "ListButton", P.accent_ink())
	_border(t, "ListButton", "normal", P.rule())
	_fill(t, "ListButton", "focus", P.row_focus())
	_border(t, "ListButton", "focus", P.accent_fill())

	# Panels the app itself uses, e.g. on the settings pages
	_fill(t, "SongoPanel", "panel", P.panel())
	_border(t, "SongoPanel", "panel", P.rule())

	# Scrollbar: slatted rail in page colors, board-colored grabber when active
	var rail := t.get_stylebox("scroll", "VScrollBar") as StyleBoxTexture
	if rail and rail.texture is GradientTexture2D:
		var slats: Gradient = (rail.texture as GradientTexture2D).gradient
		slats.colors = PackedColorArray([Color("f4f2ec") if light else P.CELL, P.rule() if light else P.BOARD_BG])
	_fill(t, "VScrollBar", "scroll_focus", Color("f4f2ec") if light else P.CELL)
	_border(t, "VScrollBar", "scroll_focus", P.accent_fill())
	for style_name in ["grabber_highlight", "grabber_pressed"]:
		_fill(t, "VScrollBar", style_name, P.accent_fill())
		_border(t, "VScrollBar", style_name, P.accent_fill().darkened(0.35 if light else 0.45))
	# Idle grabber: a mid grey that stands clear of the rail in either mode.
	_fill(t, "VScrollBar", "grabber", Color("8f897d") if light else Color("b9b5aa"))
	_border(t, "VScrollBar", "grabber", Color("5f5a51") if light else Color("5d5a52"))

func _fill(t: Theme, type: String, style_name: String, color: Color) -> void:
	var style := t.get_stylebox(style_name, type) as StyleBoxFlat
	if style: style.bg_color = color

func _border(t: Theme, type: String, style_name: String, color: Color) -> void:
	var style := t.get_stylebox(style_name, type) as StyleBoxFlat
	if style: style.border_color = color

# Some of the app's own pieces (flash messages, the info panel, settings
# rows) draw a fixed dark panel but take their text color from the theme,
# which is ink in light mode. Any label sitting on a dark panel without a
# color of its own gets the light lettering instead. That's also the dark
# mode default, so nothing needs undoing when switching back.
func _on_node_added(node: Node) -> void:
	if node is Label and P.light():
		# Deferred so the label's panel has its final color.
		_fix_label.call_deferred(node)
	if str(node.name) in SHUFFLE_PARTS:
		_sync_shuffle_row.call_deferred(node)

func _fix_labels_on_dark_panels(node: Node) -> void:
	for label in node.find_children("*", "Label", true, false):
		_fix_label(label)

func _fix_label(label: Label) -> void:
	if not is_instance_valid(label) or not label.is_inside_tree(): return
	# Labels with their own color or a styled type (like DepartureDim) are
	# already colored on purpose.
	if label.has_theme_color_override("font_color") or label.theme_type_variation != &"": return
	if _sits_on_dark_panel(label):
		label.add_theme_color_override("font_color", P.TEXT)

func _sits_on_dark_panel(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null and parent != self:
		if parent is PanelContainer or parent is Panel:
			var style := (parent as Control).get_theme_stylebox("panel") as StyleBoxFlat
			if style and style.bg_color.a > 0.5:
				return style.bg_color.get_luminance() < 0.35
		parent = parent.get_parent()
	return false

func _sync_shuffle_row(part: Node) -> void:
	if not is_instance_valid(part) or part.owner == null: return
	var button := part.owner.get_node_or_null("%ShuffleButton") as Button
	if button == null: return
	var color_name := "font_focus_color" if button.has_focus() else "font_color"
	# Read from the Theme itself; the button's cached copy updates a frame late.
	(part as CanvasItem).modulate = get_tree().root.theme.get_color(color_name, "ListButton")
