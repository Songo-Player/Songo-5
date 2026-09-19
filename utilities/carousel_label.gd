extends Label
class_name CarouselLabel

@export var carousel_speed: float = 40.0  # pixels per second
@export var pause_duration: float = 2.5   # seconds to pause at each end
@export var gap: float = 50.0             # space between repeated texts
@export var font_color: Color = Color(1,1,1,1)

const SCROLL_THRESHOLD_MARGIN: float = 1.0  # avoid flip-flopping when text width ~= label width

var _full_text: String = ""
var _text_width: float = 0.0
var _is_scrolling: bool = false
var _offset: float = 0.0
var _pause_timer: float = 0.0

func _ready() -> void:
	_full_text = text
	clip_text = true
	text_overrun_behavior = 0
	connect("resized", Callable(self, "_on_resized"))

func _process(delta: float) -> void:
	if not _is_scrolling:
		return

	if _pause_timer > 0.0:
		_pause_timer -= delta
		return

	# Clamp delta so resuming from a suspended/backgrounded app (which can
	# report a large delta on the first frame back) can't overshoot the
	# wrap point by a huge margin in one step.
	_offset += carousel_speed * minf(delta, 0.1)
	if _offset >= _text_width + gap:
		_offset = 0.0
		_pause_timer = pause_duration

	queue_redraw()

func _draw() -> void:
	if not _is_scrolling:
		return

	var font := get_theme_font("font")
	if font == null:
		return
	var font_size := get_theme_font_size("font_size")

	# Draw original text and repeated copy
	font.draw_string(get_canvas_item(), Vector2(-_offset, font_size + 3), _full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, font_color)
	font.draw_string(get_canvas_item(), Vector2(_text_width + gap - _offset, font_size + 3), _full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, font_color)

func set_carousel_text(new_text: String) -> void:
	text = new_text
	_full_text = new_text
	#await get_tree().process_frame
	_check_scroll_needed()

func _check_scroll_needed() -> void:
	var font := get_theme_font("font")
	if font == null:
		return
	var font_size := get_theme_font_size("font_size")
	_text_width = font.get_string_size(_full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	# Require the text to overflow by more than a small margin before
	# scrolling kicks in. Without this margin, when the text width lands
	# almost exactly on the label's width, sub-pixel jitter in size.x
	# across layout passes flips _is_scrolling back and forth every time
	# `resized` fires, which was observed to hang/crash on lower-powered
	# ARM64 devices.
	_is_scrolling = _text_width > size.x + SCROLL_THRESHOLD_MARGIN

	_offset = 0.0
	_pause_timer = pause_duration
	visible_characters = 0 if _is_scrolling else -1  # -1 shows text normally

	queue_redraw()

func _on_resized() -> void:
	_check_scroll_needed()
