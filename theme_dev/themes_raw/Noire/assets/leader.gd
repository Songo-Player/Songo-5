@tool
extends Control
## Dot leaders, like a ledger or a typed index: a row of dots from the end of
## one label's text to the start of another. Fills its parent and draws
## behind both labels, measuring where they actually are.

const P = preload("palette.gd")

@export var from_label: NodePath
@export var to_label: NodePath
@export var dot_color := Color(P.TEXT_DIM, 0.6):
	set(value):
		dot_color = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for path in [from_label, to_label]:
		var label := get_node_or_null(path) as Control
		if label: label.resized.connect(queue_redraw)
		if label: label.item_rect_changed.connect(queue_redraw)

func _draw() -> void:
	var from := get_node_or_null(from_label) as Label
	var to := get_node_or_null(to_label) as Label
	if from == null or to == null or not from.is_visible_in_tree(): return
	var font := from.get_theme_font("font")
	var font_size := from.get_theme_font_size("font_size")
	var text_width := minf(font.get_string_size(from.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, from.size.x)
	var origin := get_global_transform().affine_inverse()
	var start := (origin * from.global_position).x + text_width + 8.0
	var to_text := to.get_theme_font("font").get_string_size(to.text, HORIZONTAL_ALIGNMENT_LEFT, -1, to.get_theme_font_size("font_size")).x
	var to_left := (origin * to.global_position).x
	if to.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		to_left += to.size.x - to_text
	var end := to_left - 8.0
	var from_rect_y := (origin * from.global_position).y
	var y := roundf(from_rect_y + from.size.y / 2.0 + font_size * 0.28)
	var x := ceilf(start / 5.0) * 5.0  # dots line up row to row
	while x < end:
		draw_rect(Rect2(x, y, 1.5, 1.5), dot_color)
		x += 5.0

func refresh() -> void:
	queue_redraw()
