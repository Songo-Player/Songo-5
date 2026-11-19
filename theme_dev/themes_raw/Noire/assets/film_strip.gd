@tool
extends Control
## A strip of film stock: a dark band with sprocket holes punched along the
## top and bottom edges. Sits behind the footer's text.

const P = preload("palette.gd")

@export var stock_color := Color("0d0d0f"):
	set(value):
		stock_color = value
		queue_redraw()
@export var hole_color := Color("3a3a40"):
	set(value):
		hole_color = value
		queue_redraw()
## Slides the holes along, so the strip can be wound on.
@export var offset := 0.0:
	set(value):
		offset = value
		queue_redraw()

const PITCH := 12.0
const HOLE := Vector2(6, 3)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), stock_color)
	var x := fmod(offset, PITCH) - PITCH
	while x < size.x:
		draw_rect(Rect2(Vector2(roundf(x), 2), HOLE), hole_color)
		draw_rect(Rect2(Vector2(roundf(x), size.y - 2 - HOLE.y), HOLE), hole_color)
		x += PITCH
