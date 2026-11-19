extends PanelContainer
## The page everything sits on: graph paper (drawn by graph_paper.gdshader),
## with a paperclip and a few pencil doodles in the margins. Also keeps the hand-drawn wobble in step
## with the Wobble setting, and fixes text on the app's own dark panels.

const P = preload("../assets/palette.gd")
const Squiggle = preload("../assets/squiggle.gd")

func _ready() -> void:
	ThemeManager.theme_settings_updated.connect(func(): Squiggle.refresh())
	Controller.page_changed.connect(_show_clip)
	%GraphPaper.resized.connect(_size_paper)
	_size_paper()
	_show_clip()
	get_tree().node_added.connect(_on_node_added)
	_fix_labels_on_dark_panels.call_deferred(get_tree().root)

# The shader works in pixels, so it's told the sheet's size.
func _size_paper() -> void:
	(%GraphPaper.material as ShaderMaterial).set_shader_parameter("rect_size", %GraphPaper.size)

# The paperclip sits where the main menu leaves room for it; on other pages
# it would land on the content, so it's tucked away there.
func _show_clip() -> void:
	$MarginContainer.visible = Controller.nav_label.size() <= 1

# Some of the app's own pieces (flash messages, the info panel) draw a fixed
# dark panel but take their text color from the theme, which is pencil grey
# here. Any label sitting on a dark panel without a color of its own gets
# paper white instead.
func _on_node_added(node: Node) -> void:
	if node is Label:
		# Deferred so the label's panel has its final color.
		_fix_label.call_deferred(node)

func _fix_labels_on_dark_panels(node: Node) -> void:
	for label in node.find_children("*", "Label", true, false):
		_fix_label(label)

func _fix_label(label: Label) -> void:
	if not is_instance_valid(label) or not label.is_inside_tree(): return
	if label.has_theme_color_override("font_color") or label.theme_type_variation != &"": return
	if _sits_on_dark_panel(label):
		label.add_theme_color_override("font_color", P.PAPER)

func _sits_on_dark_panel(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null and parent != self:
		if parent is PanelContainer or parent is Panel:
			var style := (parent as Control).get_theme_stylebox("panel") as StyleBoxFlat
			if style and style.bg_color.a > 0.5:
				return style.bg_color.get_luminance() < 0.35
		parent = parent.get_parent()
	return false
