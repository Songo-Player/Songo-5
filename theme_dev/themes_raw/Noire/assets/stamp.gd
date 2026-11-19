@tool
extends Control
## A rubber stamp: the text in a double box, slightly worn, in the accent.
## stamp() slams a new one down with a little overshoot.

const FONT = preload("font_title.tres")

@export var text := "OPEN CASE":
	set(value):
		text = value
		queue_redraw()
@export var color := Color("c8102e"):
	set(value):
		color = value
		queue_redraw()
## Wear marks are dabs of this, so it should match whatever's under the stamp.
@export var paper_color := Color("e4ddcc"):
	set(value):
		paper_color = value
		queue_redraw()
@export var font_size := 17

var _tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func(): pivot_offset = size / 2.0)
	pivot_offset = size / 2.0

func stamp(new_text: String, animate := true) -> void:
	if new_text == text and modulate.a > 0.99: return
	text = new_text
	if not animate or Engine.is_editor_hint():
		scale = Vector2.ONE
		modulate.a = 1.0
		return
	if _tween: _tween.kill()
	scale = Vector2(1.8, 1.8)
	modulate.a = 0.0
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.1)

func _draw() -> void:
	if text == "": return
	var text_size := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var box := Rect2(Vector2.ZERO, Vector2(text_size.x + 22.0, font_size + 14.0))
	box.position = ((size - box.size) / 2.0).round()
	var ink := Color(color, 0.88)
	draw_rect(box, ink, false, 2.0)
	draw_rect(box.grow(-4.0), ink, false, 1.0)
	var ascent := FONT.get_ascent(font_size)
	var baseline := box.position.y + (box.size.y - FONT.get_height(font_size)) / 2.0 + ascent
	draw_string(FONT, Vector2(box.position.x + 11.0, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)

	# Wear: where the rubber didn't quite meet the paper.
	var rng := RandomNumberGenerator.new()
	rng.seed = text.hash()
	for i in 46:
		var at := box.position + Vector2(rng.randf() * box.size.x, rng.randf() * box.size.y)
		var dab := Vector2(rng.randf_range(1.0, 2.5), rng.randf_range(1.0, 2.0))
		draw_rect(Rect2(at, dab), Color(paper_color, rng.randf_range(0.5, 0.95)))
