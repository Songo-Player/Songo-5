@tool
extends Control
## A horizontal rule broken by a diamond, with a short second line either
## side of it, like the dividers on a 1940s title card.

const P = preload("palette.gd")

@export var line_color := P.TEXT_DIM:
	set(value):
		line_color = value
		queue_redraw()
@export var gem_color := Color(P.DEFAULT_ACCENT):
	set(value):
		gem_color = value
		queue_redraw()
## 0 centres the diamond, anything else puts it this many pixels from the left.
@export var gem_at := 0.0:
	set(value):
		gem_at = value
		queue_redraw()

## Keeps gem_color in the theme's accent as settings change.
@export var follow_accent := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if follow_accent and not Engine.is_editor_hint():
		_follow_accent()
		ThemeManager.theme_settings_updated.connect(_follow_accent)

func _follow_accent() -> void:
	gem_color = P.accent()

func _draw() -> void:
	var y := roundf(size.y / 2.0) + 0.5
	var mid := gem_at if gem_at > 0.0 else roundf(size.x / 2.0)
	var gap := 8.0
	draw_line(Vector2(0, y), Vector2(mid - gap, y), line_color, 1.0)
	draw_line(Vector2(mid + gap, y), Vector2(size.x, y), line_color, 1.0)
	# The doubled line close to the diamond.
	var reach := minf(28.0, mid - gap)
	if reach > 4.0:
		draw_line(Vector2(mid - gap - reach, y - 3), Vector2(mid - gap, y - 3), Color(line_color, 0.5), 1.0)
		draw_line(Vector2(mid + gap, y + 3), Vector2(mid + gap + reach, y + 3), Color(line_color, 0.5), 1.0)
	var r := 4.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(mid, y - r), Vector2(mid + r, y), Vector2(mid, y + r), Vector2(mid - r, y)
	]), gem_color)
