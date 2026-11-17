@tool
extends Control
## The flight path on the boarding pass: a dotted route from departure to
## arrival, solid behind the marker to show how far through the song we are.

const P = preload("palette.gd")

@export_range(0.0, 1.0) var progress := 0.35:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if absf(value - progress) < 0.002: return
		progress = value
		queue_redraw()
@export var ink := P.INK:
	set(value):
		ink = value
		queue_redraw()
@export var marker_color := Color(P.DEFAULT_BOARD):
	set(value):
		marker_color = value
		queue_redraw()

func _draw() -> void:
	var mid := roundf(size.y / 2.0)
	var left := 5.0
	var right := size.x - 5.0
	var at := lerpf(left, right, progress)

	# Flown: solid. Still to fly: dotted.
	draw_line(Vector2(left, mid), Vector2(at, mid), ink, 2.0)
	var x := at + 6.0
	while x < right - 4.0:
		draw_rect(Rect2(x, mid - 1, 3, 2), Color(ink, 0.45))
		x += 7.0

	draw_circle(Vector2(left, mid), 4.0, ink)                    # origin
	draw_arc(Vector2(right, mid), 4.0, 0, TAU, 16, ink, 2.0)     # destination

	# The aircraft: a little chevron pointing toward the destination.
	var nose := Vector2(at + 7.0, mid)
	var points := PackedVector2Array([nose, Vector2(at - 5.0, mid - 6.0), Vector2(at - 2.0, mid), Vector2(at - 5.0, mid + 6.0)])
	draw_colored_polygon(points, marker_color)
	draw_polyline(points + PackedVector2Array([nose]), ink, 1.0, true)
