@tool
extends Control
## The tear line between a boarding pass and its stub: card stock with a
## dashed rule and a half-circle notch bitten out of the top and bottom.

const P = preload("palette.gd")

@export var paper := P.PAPER:
	set(value):
		paper = value
		queue_redraw()
@export var notch_color := P.BOARD_BG:
	set(value):
		notch_color = value
		queue_redraw()
@export var notch_radius := 7.0

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), paper)
	var cx := size.x / 2.0
	var y := notch_radius + 6.0
	while y < size.y - notch_radius - 6.0:
		draw_rect(Rect2(cx - 1.0, y, 2.0, 5.0), Color(P.INK, 0.35))
		y += 10.0
	draw_circle(Vector2(cx, 0), notch_radius, notch_color)
	draw_circle(Vector2(cx, size.y), notch_radius, notch_color)
