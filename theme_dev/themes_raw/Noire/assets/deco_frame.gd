@tool
extends Control
## An art deco border: a hairline outer rule and an inner rule with square
## notches cut into its corners, a small diamond set into each notch. Sits as
## the first child of a PanelContainer so it's drawn behind the content.

const P = preload("palette.gd")

@export var line_color := P.RULE:
	set(value):
		line_color = value
		queue_redraw()
@export var gem_color := Color(P.DEFAULT_ACCENT):
	set(value):
		gem_color = value
		queue_redraw()
@export var inset := 4.0:
	set(value):
		inset = value
		queue_redraw()
@export var notch := 9.0:
	set(value):
		notch = value
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
	var w := size.x
	var h := size.y
	if w < notch * 3.0 or h < notch * 3.0: return
	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), line_color, false, 1.0)

	var a := inset + 0.5
	var c := notch
	var points := PackedVector2Array([
		Vector2(a + c, a), Vector2(w - a - c, a), Vector2(w - a - c, a + c), Vector2(w - a, a + c),
		Vector2(w - a, h - a - c), Vector2(w - a - c, h - a - c), Vector2(w - a - c, h - a),
		Vector2(a + c, h - a), Vector2(a + c, h - a - c), Vector2(a, h - a - c),
		Vector2(a, a + c), Vector2(a + c, a + c), Vector2(a + c, a),
	])
	draw_polyline(points, line_color, 1.0)

	for corner in [Vector2(a + c / 2.0, a + c / 2.0), Vector2(w - a - c / 2.0, a + c / 2.0),
			Vector2(w - a - c / 2.0, h - a - c / 2.0), Vector2(a + c / 2.0, h - a - c / 2.0)]:
		_gem(corner, 2.5)

func _gem(at: Vector2, r: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)
	]), gem_color)
