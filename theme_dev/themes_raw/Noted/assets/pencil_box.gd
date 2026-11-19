@tool
extends "sketch_control.gd"
## A box sketched in pencil round whatever sits on top of it: buttons,
## keycaps, little labels. Can be colored in with highlighter.

@export var color := P.PENCIL_DARK
@export var width := 2.0
@export var seed := 0
## Highlighter fill, from 0 (none) to 1. Tween it for a smooth change.
@export_range(0.0, 1.0) var marked := 0.0:
	set(value):
		marked = value
		queue_redraw()
@export var mark_color := P.HIGHLIGHTER
## Pulls the box in from the edges, so overshooting strokes stay inside.
@export var inset := 3.0

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size).grow(-inset)
	if marked > 0.01:
		# Highlighter goes on a little crooked and past the box.
		var mark := PackedVector2Array([
			r.position + Vector2(-2, 3), Vector2(r.end.x + 3, r.position.y + 1),
			r.end + Vector2(1, -2), Vector2(r.position.x - 1, r.end.y)])
		draw_colored_polygon(mark, Color(mark_color, 0.75 * marked))
	Sketch.rect(self, r, color, width, seed)
