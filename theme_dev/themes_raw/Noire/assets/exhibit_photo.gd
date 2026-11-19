@tool
extends Control
## The cover as an evidence photo: a glossy print with a white border and a
## typed label along the bottom, clipped to the file with a paperclip. With
## no cover, the print is a dark frame marked NO PHOTO ON FILE. Lay it out
## in a plain Control so its tilt holds; it fits and centres itself.

const P = preload("palette.gd")
const FONT = preload("font_type.tres")
const SILVER = preload("silver_print.tres")
const NO_PHOTO_ICON = preload("res://assets/music.svg")

const BORDER := 7.0
const LABEL_H := 20.0

@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
@export var caption := "EXHIBIT A":
	set(value):
		caption = value
		queue_redraw()
@export var max_print := 180.0:
	set(value):
		max_print = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

## Develops the print in black and white, or leaves the cover in color.
func set_monochrome(on: bool) -> void:
	material = SILVER if on else null

## The size of the print (border and label included) at the current size.
func frame_size() -> Vector2:
	var side := minf(minf(size.x - 16.0, size.y - LABEL_H - 16.0 - BORDER * 2.0) , max_print)
	side = maxf(side, 24.0)
	return Vector2(side + BORDER * 2.0, side + BORDER * 2.0 + LABEL_H)

func _draw() -> void:
	var frame := Rect2(((size - frame_size()) / 2.0).round(), frame_size())
	var side := frame.size.x - BORDER * 2.0

	# Shadow on the desk, then the print.
	draw_rect(Rect2(frame.position + Vector2(4, 5), frame.size), Color(0, 0, 0, 0.45))
	draw_rect(frame, P.PHOTO_BORDER)
	var image := Rect2(frame.position + Vector2(BORDER, BORDER), Vector2(side, side))
	if texture:
		draw_texture_rect(texture, image, false)
	else:
		draw_rect(image, Color("1b1b1e"))
		var icon_side := side * 0.32
		draw_texture_rect(NO_PHOTO_ICON, Rect2(image.get_center() - Vector2(icon_side, icon_side) / 2.0 - Vector2(0, 8), Vector2(icon_side, icon_side)), false, Color(P.TEXT_DIM, 0.6))
		var note := "NO PHOTO ON FILE"
		var note_w := FONT.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(FONT, Vector2(image.get_center().x - note_w / 2.0, image.end.y - 14.0), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, P.TEXT_DIM)
	# A gloss of light over the print's upper corner.
	draw_colored_polygon(PackedVector2Array([
		image.position, image.position + Vector2(side * 0.45, 0), image.position + Vector2(0, side * 0.45)
	]), Color(1, 1, 1, 0.05))

	# The typed label on the bottom border.
	var caption_w := FONT.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(FONT, Vector2(frame.get_center().x - caption_w / 2.0, frame.end.y - 7.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, P.INK)


func _loop(at: Vector2, w: float, h: float) -> PackedVector2Array:
	var r := w / 2.0
	var points := PackedVector2Array()
	points.append(at + Vector2(w, h - r))
	for i in 9:  # bottom bend
		var a := float(i) / 8.0 * PI
		points.append(at + Vector2(r + cos(a) * r, h - r + sin(a) * r))
	points.append(at + Vector2(0, r))
	for i in 9:  # top bend
		var a := PI + float(i) / 8.0 * PI
		points.append(at + Vector2(r + cos(a) * r, r + sin(a) * r))
	points.append(at + Vector2(w, h * 0.7))
	return points
