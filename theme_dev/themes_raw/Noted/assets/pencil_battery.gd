@tool
extends "sketch_control.gd"
## The battery, doodled: a pencil box with a nub, scribbled in to the
## charge level. Low turns the scribble red; charging adds a lightning bolt.

## Charge from 0 to 1, or below 0 when unknown.
@export var level := 1.0:
	set(value):
		level = value
		queue_redraw()
@export var charging := false:
	set(value):
		charging = value
		queue_redraw()

func _draw() -> void:
	var body := Rect2(Vector2(2, 3), Vector2(size.x - 7, size.y - 6))
	Sketch.rect(self, body, P.PENCIL_DARK, 1.8, 3, 1.5)
	var nub := Rect2(Vector2(body.end.x + 1, size.y * 0.35), Vector2(3, size.y * 0.3))
	draw_rect(nub, P.PENCIL_DARK)
	if level > 0.0:
		var fill := Rect2(body.position + Vector2(3, 3), Vector2((body.size.x - 6) * clampf(level, 0, 1), body.size.y - 6))
		Sketch.hatch(self, fill, P.RED_PEN if level < 0.2 and not charging else P.PENCIL, 3.0, 1.4, 11)
	elif level < 0.0:
		Sketch.line(self, body.position + Vector2(5, body.size.y / 2), body.end - Vector2(5, body.size.y / 2), P.PENCIL_LIGHT, 1.5, 5)
	if charging:
		var c := body.get_center()
		draw_polyline(PackedVector2Array([c + Vector2(2, -6), c + Vector2(-3, 1), c + Vector2(2, 0), c + Vector2(-2, 7)]),
			P.PENCIL_DARK, 2.0, true)
