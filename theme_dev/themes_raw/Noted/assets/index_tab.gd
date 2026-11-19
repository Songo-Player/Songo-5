@tool
extends Button
## A notebook index tab sticking up from the top of the sticky note, one per
## menu entry, with the entry's icon on it. The selected tab rises a little
## and runs down into the note, so the two read as one piece of paper.

const P = preload("palette.gd")
const Squiggle = preload("squiggle.gd")

## Where the tab joins the note, as a fraction lifted when selected.
@export_range(0.0, 1.0) var lift := 0.0:
	set(value):
		lift = value
		queue_redraw()
		if _icon: _position_icon()
@export var fill := Color("fffab1"):
	set(value):
		fill = value
		queue_redraw()
@export var edge := Color("b3ae7b"):
	set(value):
		edge = value
		queue_redraw()
@export var tab_icon: Texture2D:
	set(value):
		tab_icon = value
		if _icon: _icon.texture = value

## How far the selected tab rises, and how far it reaches into the note to
## cover the note's top edge.
const RISE := 6.0
const REACH := 3.0
const SLANT := 10.0

var _icon: TextureRect

func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, empty)
	_icon = TextureRect.new()
	_icon.texture = tab_icon
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.modulate = P.PENCIL
	_icon.material = Squiggle.material(2.0)
	add_child(_icon)
	resized.connect(_position_icon)
	_position_icon()

func _position_icon() -> void:
	var side := minf(size.x - SLANT * 2.0 - 8.0, size.y - RISE - 14.0)
	_icon.size = Vector2(side, side)
	_icon.position = Vector2((size.x - side) / 2.0, RISE * (1.0 - lift) + (size.y - RISE - side) / 2.0 + 2.0)

func _draw() -> void:
	var top := RISE * (1.0 - lift)
	var bottom := size.y + REACH * lift
	var w := size.x
	var outer := PackedVector2Array([
		Vector2(0, bottom), Vector2(SLANT, top), Vector2(w - SLANT, top), Vector2(w, bottom)])
	var inner := PackedVector2Array([
		Vector2(2, bottom), Vector2(SLANT + 1.5, top + 2), Vector2(w - SLANT - 1.5, top + 2), Vector2(w - 2, bottom)])
	draw_colored_polygon(outer, edge)
	# Tabs further back are a shade darker, as if in the note's shadow.
	draw_colored_polygon(inner, fill.lerp(edge, 0.18 * (1.0 - lift)))
