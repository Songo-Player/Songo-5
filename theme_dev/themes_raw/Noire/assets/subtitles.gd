extends Control
## Lyrics as old film subtitles: white type with a hard black edge, centred
## at the bottom of the frame. Each line fades in, holds, and fades out; a
## new line arriving cuts the old one short.

const FONT = preload("font_type.tres")

const FADE_TIME := 0.18
const HOLD_TIME := 6.0
const FONT_SIZE := 17

@export var text_color := Color("fffaf0"):
	set(value):
		text_color = value
		for label in get_children():
			label.add_theme_color_override("font_color", value)

var _current: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func():
		for label in get_children(): label.size = size)

func show_lyric(text: String) -> void:
	_fade_out(_current)
	if text.strip_edges() == "": return
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	# The font's tall ascent (matched to the Noto fallback) leaves room above
	# each line; pull the two lines together so they fit the strip.
	label.add_theme_constant_override("line_spacing", -7)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.modulate.a = 0.0
	add_child(label)
	label.size = size
	_current = label

	var tween := label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, FADE_TIME)
	tween.tween_interval(HOLD_TIME)
	tween.tween_callback(_fade_out.bind(label))

## Takes the showing line away, e.g. when the song changes.
func clear() -> void:
	_fade_out(_current)

func _fade_out(label: Label) -> void:
	if label == null or not is_instance_valid(label) or label.has_meta("leaving"): return
	label.set_meta("leaving", true)
	if label == _current: _current = null
	var tween := label.create_tween()
	tween.tween_property(label, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(label.queue_free)
