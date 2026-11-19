@tool
extends "sketch_control.gd"
## The song's progress on a clear plastic school ruler: tick marks along the
## top edge, highlighter swiped along it as the song plays, and a little
## pencil arrow under the current spot.

const TICK_STEP := 6.0

@export_range(0.0, 1.0) var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()

func _draw() -> void:
	var body := Rect2(Vector2(2, 2), Vector2(size.x - 4, size.y - 10))
	draw_rect(body, Color(1, 1, 1, 0.55))
	# Highlighter along the ruler's middle, up to where the song is.
	var band := Rect2(body.position + Vector2(3, body.size.y * 0.42), Vector2((body.size.x - 6) * progress, body.size.y * 0.5))
	if band.size.x > 0.5:
		draw_colored_polygon(PackedVector2Array([
			band.position + Vector2(0, 1), Vector2(band.end.x, band.position.y),
			band.end + Vector2(0, -1), Vector2(band.position.x, band.end.y)]), Color(P.HIGHLIGHTER, 0.85))
	# Ticks: short ones every step, longer every fifth, longest every tenth.
	var count := int((body.size.x - 6) / TICK_STEP)
	for i in count + 1:
		var x := body.position.x + 3 + i * TICK_STEP
		var length := body.size.y * (0.38 if i % 10 == 0 else (0.26 if i % 5 == 0 else 0.15))
		draw_line(Vector2(x, body.position.y), Vector2(x, body.position.y + length), Color(P.PENCIL, 0.8), 1.0)
	Sketch.rect(self, body, P.PENCIL_DARK, 1.6, 21, 2.0)
	# The arrow pointing up at the current spot.
	var tip := Vector2(body.position.x + 3 + (body.size.x - 6) * progress, body.end.y + 2)
	Sketch.line(self, tip, tip + Vector2(-4, 7), P.PENCIL_DARK, 1.8, 31, 0.6)
	Sketch.line(self, tip, tip + Vector2(4, 7), P.PENCIL_DARK, 1.8, 37, 0.6)
