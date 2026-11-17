extends Control
## A one-line-at-a-time lyric strip. Each lyric slides in from the right,
## holds, then slides away to the left. A new lyric arriving early pushes the
## current one out as it comes in, like a conveyor, so lines never stack.

const P = preload("palette.gd")
const FONT = preload("font_regular.tres")

const SLIDE_TIME := 0.4
const HOLD_TIME := 5.0
const FONT_SIZE := 15

var _current: Label

@export var text_color := P.TEXT:
	set(value):
		text_color = value
		for label in get_children():
			label.add_theme_color_override("font_color", value)

func _ready() -> void:
	clip_contents = true
	resized.connect(_on_resized)

func show_lyric(text: String) -> void:
	_slide_out(_current)
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
	add_child(label)
	label.size = size
	label.position = Vector2(size.x, 0)
	_current = label

	var tween := _tween_for(label)
	tween.tween_property(label, "position:x", 0.0, SLIDE_TIME)
	tween.tween_interval(HOLD_TIME)
	tween.tween_callback(_slide_out.bind(label))

## Sends the showing lyric away, e.g. when the song changes.
func clear() -> void:
	_slide_out(_current)

func _slide_out(label: Label) -> void:
	if label == null or not is_instance_valid(label) or label.has_meta("leaving"): return
	label.set_meta("leaving", true)
	if label == _current: _current = null
	# Leaves from wherever it is, even partway through sliding in.
	var tween := _tween_for(label)
	tween.tween_property(label, "position:x", -size.x, SLIDE_TIME)
	tween.tween_callback(label.queue_free)

# One tween per label, replacing any it already has. Incoming and outgoing
# lines share the same curve so they travel together.
func _tween_for(label: Label) -> Tween:
	if label.has_meta("tween"):
		var old: Tween = label.get_meta("tween")
		if old and old.is_valid(): old.kill()
	var tween := label.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	label.set_meta("tween", tween)
	return tween

func _on_resized() -> void:
	for label in get_children():
		label.size = size
