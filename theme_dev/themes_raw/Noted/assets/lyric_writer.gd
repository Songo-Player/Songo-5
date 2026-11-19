extends Control
## Lyrics written out by hand on a notebook line, one at a time. A new line
## first gets the old one crossed out with a quick pencil stroke (it fades
## as it's struck through), then writes itself in letter by letter. Lines
## never stack: a lyric arriving mid-write crosses out whatever is there.

const P = preload("palette.gd")
const Sketch = preload("sketch.gd")
const Squiggle = preload("squiggle.gd")
const FONT = preload("font_hand.tres")

const FONT_SIZE := 22
const STRIKE_TIME := 0.25
const SECONDS_PER_LETTER := 0.035
const MAX_WRITE_TIME := 1.4

var _current: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_on_resized)

func show_lyric(text: String) -> void:
	var delay := 0.0
	if _current and is_instance_valid(_current):
		_strike(_current)
		delay = STRIKE_TIME
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", P.PENCIL_DARK)
	label.material = Squiggle.material(0.15)
	label.visible_ratio = 0.0
	add_child(label)
	label.size = size
	_current = label
	var tween := label.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(label, "visible_ratio", 1.0, minf(text.length() * SECONDS_PER_LETTER, MAX_WRITE_TIME))

## Crosses out whatever is showing, e.g. when the song changes.
func clear() -> void:
	if _current and is_instance_valid(_current): _strike(_current)
	_current = null

# A pencil stroke drawn across the written part of the line, then the line
# and its stroke fade away together.
func _strike(label: Label) -> void:
	if label.has_meta("struck"): return
	label.set_meta("struck", true)
	var font := label.get_theme_font("font")
	var shown := label.text.left(int(label.text.length() * label.visible_ratio))
	var width := minf(font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x, label.size.x)
	var full := minf(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x, label.size.x)
	var start := (label.size.x - full) / 2.0
	var stroke := _Stroke.new()
	stroke.from = Vector2(start - 4, label.size.y * 0.55)
	stroke.to = Vector2(start + width + 4, label.size.y * 0.45)
	label.add_child(stroke)
	stroke.size = label.size
	var tween := label.create_tween()
	tween.tween_property(stroke, "reach", 1.0, STRIKE_TIME * 0.6)
	tween.tween_property(label, "modulate:a", 0.0, STRIKE_TIME)
	tween.tween_callback(label.queue_free)

func _on_resized() -> void:
	for label in get_children():
		label.size = size

## The cross-out stroke, drawn from left to right as `reach` goes 0 to 1.
class _Stroke extends Control:
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var reach := 0.0:
		set(value):
			reach = value
			queue_redraw()

	func _draw() -> void:
		if reach <= 0.0: return
		Sketch.line(self, from, from.lerp(to, reach), P.PENCIL_DARK, 2.2, 7, 0.8)
