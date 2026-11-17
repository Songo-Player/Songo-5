extends Control
## A rough picture of the equalizer settings: one point per band, joined by a
## smooth line, from 31hz on the left to 16khz on the right. Call
## queue_redraw() after the bands change.

# Same look as the music directory list in Data and Storage: the default light
# StyleBoxFlat grey with the dark text colour used on it
const INK := Color(0.137255, 0.129412, 0.121569, 1)
const LINE_COLOR := INK
const ZERO_COLOR := Color(INK, 0.55)
const GRID_COLOR := Color(INK, 0.18)
const BG_COLOR := Color(0.6, 0.6, 0.6, 1)
const LABEL_COLOR := Color(INK, 0.85)
const LABEL_SIZE := 11
const PAD := Vector2(30, 12)
const STEPS_PER_BAND := 8

var songo_settings = SongoSettings.get_instance()

func _draw() -> void:
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	var area := Rect2(PAD, size - PAD * 2)
	if area.size.x <= 0 or area.size.y <= 0:
		return

	var font := get_theme_default_font()
	for db in [SongoEqualizer.MAX_GAIN_DB, 0.0, -12.0, SongoEqualizer.MIN_GAIN_DB]:
		var y := _y_for(db, area)
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), ZERO_COLOR if db == 0.0 else GRID_COLOR, 1.0)
		draw_string(font, Vector2(2, y + LABEL_SIZE * 0.35), "%+d" % int(db) if db != 0.0 else "0",
				HORIZONTAL_ALIGNMENT_LEFT, PAD.x - 4, LABEL_SIZE, LABEL_COLOR)

	var points: PackedVector2Array = []
	for i in SongoEqualizer.BAND_COUNT:
		points.append(Vector2(_x_for(i, area), _y_for(songo_settings.equalizer.get_band_gain(i), area)))

	# Catmull-Rom through the band points, so it reads as a curve
	var curve: PackedVector2Array = []
	for i in points.size() - 1:
		var p0 := points[max(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[min(i + 2, points.size() - 1)]
		for s in STEPS_PER_BAND:
			var t := float(s) / STEPS_PER_BAND
			var p := 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t)
			p.y = clamp(p.y, area.position.y, area.end.y)
			curve.append(p)
	curve.append(points[points.size() - 1])

	draw_polyline(curve, LINE_COLOR, 2.0, true)
	for p in points:
		draw_circle(p, 3.0, LINE_COLOR)

func _x_for(band_index: int, area: Rect2) -> float:
	return area.position.x + area.size.x * band_index / float(SongoEqualizer.BAND_COUNT - 1)

func _y_for(db: float, area: Rect2) -> float:
	var t := inverse_lerp(SongoEqualizer.MAX_GAIN_DB, SongoEqualizer.MIN_GAIN_DB, db)
	return area.position.y + area.size.y * clamp(t, 0.0, 1.0)

func _background() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = BG_COLOR
	box.set_corner_radius_all(4)
	return box
