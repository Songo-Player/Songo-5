extends Label
class_name CarouselLabel

@export var carousel_speed: float = 40.0  # pixels per second
@export var pause_duration: float = 2.5   # seconds to pause at each end
@export var gap: float = 50.0             # space between repeated texts
@export var font_color: Color = Color(1,1,1,1)

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

	_offset += carousel_speed * delta
	if _offset >= _text_width + gap:
		_offset = 0.0
		_pause_timer = pause_duration

	queue_redraw()

func _draw() -> void:
	if not _is_scrolling:
		return

	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")

	# Draw original text and repeated copy
	font.draw_string(get_canvas_item(), Vector2(-_offset, font_size + 3), _full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, font_color)
	font.draw_string(get_canvas_item(), Vector2(_text_width + gap - _offset, font_size + 3), _full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, font_color)

func set_carousel_text(new_text: String) -> void:
	text = new_text
	_full_text = new_text
	#await get_tree().process_frame
	_check_scroll_needed()

func _check_scroll_needed_old() -> void:
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	_text_width = font.get_string_size(_full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_is_scrolling = _text_width > size.x
	_offset = 0.0
	_pause_timer = pause_duration
	queue_redraw()
	
func _check_scroll_needed() -> void:
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	_text_width = font.get_string_size(_full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# Scroll only if the text is wider than the label
	_is_scrolling = _text_width > size.x + 2.0

	_offset = 0.0
	_pause_timer = pause_duration

	if _is_scrolling:
		visible_characters = 0
	else:
		visible_characters = -1  # show text normally

	queue_redraw()

func _on_resized() -> void:
	_check_scroll_needed()
