@tool
extends RefCounted
## Pencil drawing helpers. squiggle.gdshader boils textures (text, icons),
## but drawn lines need their own wobble, so these jitter a shape's points
## and pick new jitter at the same few frames a second. Lines overshoot
## their corners a little, the way a quick pencil sketch does.

const P = preload("palette.gd")
const FPS := 6.0

## The current boil frame. Held at 0 when the Wobble setting is off.
static func frame() -> int:
	if not P.wobble(): return 0
	return int(Time.get_ticks_msec() / 1000.0 * FPS)

## A wobbly line from a to b, split into short pieces each nudged a little.
static func line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width := 2.0, seed := 0, amount := 1.2) -> void:
	ci.draw_polyline(_jitter(_subdivide([a, b]), seed, amount), color, width, true)

## A rectangle drawn as four separate strokes that run a little past each
## corner.
static func rect(ci: CanvasItem, r: Rect2, color: Color, width := 2.0, seed := 0, overshoot := 3.0) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var along := (b - a).normalized()
		line(ci, a - along * overshoot * _unit(seed + i * 7), b + along * overshoot * _unit(seed + i * 7 + 3),
			color, width, seed + i * 13)

## A loose hand-drawn loop round an ellipse, ending past where it started.
static func loop(ci: CanvasItem, center: Vector2, radii: Vector2, color: Color, width := 2.0, seed := 0) -> void:
	var points := PackedVector2Array()
	var start := _unit(seed) * TAU
	var steps := 40
	for i in steps + 5:
		var angle := start + TAU * i / steps
		# The loop drifts outward a touch as it goes round, so the ends miss.
		var drift := 1.0 + 0.06 * float(i) / steps
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y) * drift)
	ci.draw_polyline(_jitter(points, seed, 0.8), color, width, true)

## A filled area scribbled in with diagonal pencil strokes.
static func hatch(ci: CanvasItem, r: Rect2, color: Color, spacing := 4.0, width := 1.5, seed := 0) -> void:
	var x := r.position.x - r.size.y
	var i := 0
	while x < r.end.x:
		var a := Vector2(x, r.end.y)
		var b := Vector2(x + r.size.y, r.position.y)
		var clipped := Geometry2D.clip_polyline_with_polygon(PackedVector2Array([a, b]), PackedVector2Array([
			r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
		for piece in clipped:
			if piece.size() == 2: line(ci, piece[0], piece[1], color, width, seed + i, 0.6)
		x += spacing
		i += 1

static func _subdivide(points: Array, step := 8.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var pieces := maxi(1, int(a.distance_to(b) / step))
		for j in pieces:
			out.append(a.lerp(b, float(j) / pieces))
	out.append(points[points.size() - 1])
	return out

static func _jitter(points: PackedVector2Array, seed: int, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var f := frame()
	for i in points.size():
		var h := seed * 7919 + f * 104729 + i * 31
		out.append(points[i] + Vector2(_unit(h) - 0.5, _unit(h + 17) - 0.5) * 2.0 * amount)
	return out

# A repeatable pseudo-random number from 0 to 1.
static func _unit(n: int) -> float:
	return fposmod(sin(float(n) * 12.9898) * 43758.5453, 1.0)
