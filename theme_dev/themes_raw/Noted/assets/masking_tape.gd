@tool
extends "sketch_control.gd"
## A strip of masking tape with torn, zigzag ends.

@export var color := Color("efe3c2", 0.88)
@export var seed := 0
## How long the strip is, from the left. Below 0, it fills the control.
@export var length := -1.0:
	set(value):
		length = value
		queue_redraw()

func _draw() -> void:
	var w := size.x if length < 0.0 else minf(length, size.x)
	var h := size.y
	var teeth := maxi(3, int(h / 4.0))
	var points := PackedVector2Array()
	# Left torn end, top to bottom.
	for i in teeth + 1:
		points.append(Vector2((2.5 if i % 2 else 0.0) + Sketch._unit(seed + i) * 1.5, h * i / teeth))
	# Right torn end, bottom to top.
	for i in range(teeth, -1, -1):
		points.append(Vector2(w - (2.5 if i % 2 else 0.0) - Sketch._unit(seed + 50 + i) * 1.5, h * i / teeth))
	draw_colored_polygon(points, color)
	# Faint lengthways creases.
	for i in 2:
		var y := h * (0.35 + 0.3 * i)
		draw_line(Vector2(4, y), Vector2(w - 4, y + 0.5), Color(1, 1, 1, 0.18), 1.0)
