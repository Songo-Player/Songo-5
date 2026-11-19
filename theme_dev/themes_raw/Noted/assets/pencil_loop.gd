@tool
extends "sketch_control.gd"
## A loose pencil circle drawn round a button's icon, colored in with
## highlighter while the button has focus. Sits behind its parent button
## (show_behind_parent), filling it.

@export var seed := 0
@export_range(0.0, 1.0) var marked := 0.0:
	set(value):
		marked = value
		queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	var radii := size / 2.0 - Vector2(4, 4)
	if marked > 0.01:
		var disc := PackedVector2Array()
		for i in 24:
			var angle := TAU * i / 24.0
			disc.append(center + Vector2(cos(angle) * radii.x * 1.02, sin(angle) * radii.y * 0.98) + Vector2(1, 1))
		draw_colored_polygon(disc, Color(P.HIGHLIGHTER, 0.8 * marked))
	Sketch.loop(self, center, radii, P.PENCIL_DARK, 2.2, seed)
