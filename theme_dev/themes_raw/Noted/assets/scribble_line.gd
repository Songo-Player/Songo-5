extends "sketch_control.gd"
## The visualizer: a pencil line underlining the song title that scribbles
## up and down with the music, like a doodle drawn in time with the beat
## (after XBop's string visualizer). Flat and calm when nothing plays.

const MIN_HZ := 40.0
const MAX_HZ := 12000.0
const DB_FLOOR := 60.0
const POINTS := 18
const SMOOTHING := 0.45

@export var amplitude := 0.42
@export var color := P.PENCIL

var spectrum
var _levels := PackedFloat32Array()

func _ready() -> void:
	super()
	spectrum = SongoPlayer.get_spectrum()
	_levels.resize(POINTS)
	_levels.fill(0.0)

# Redrawn every frame while music plays, so it keeps up with the beat.
func _always_redraw() -> bool:
	return not DeviceOS.sleeping and spectrum != null and SongoPlayer.is_playing()

func _draw() -> void:
	var playing: bool = spectrum != null and SongoPlayer.is_playing()
	var mid := size.y * 0.5
	var points := PackedVector2Array()
	for i in POINTS:
		var t := float(i) / (POINTS - 1)
		var energy := 0.0
		# The ends stay pinned so it reads as one stroke.
		if playing and i > 0 and i < POINTS - 1:
			var low := MIN_HZ * pow(MAX_HZ / MIN_HZ, float(i - 1) / (POINTS - 2))
			var high := MIN_HZ * pow(MAX_HZ / MIN_HZ, float(i) / (POINTS - 2))
			var magnitude: float = spectrum.get_magnitude_for_frequency_range(low, high).length()
			energy = clampf((linear_to_db(magnitude) + DB_FLOOR) / DB_FLOOR, 0.0, 1.0)
		_levels[i] = lerpf(_levels[i], energy, SMOOTHING)
		var direction := 1.0 if i % 2 == 0 else -1.0
		points.append(Vector2(t * size.x, mid - _levels[i] * size.y * amplitude * direction))
	var smooth := _smooth(points, 2)
	draw_polyline(Sketch._jitter(smooth, 41, 0.7), color, 2.0, true)

# Corner cutting, so the scribble curves instead of zigzagging.
func _smooth(points: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var result := points
	for _i in iterations:
		var next := PackedVector2Array([result[0]])
		for j in result.size() - 1:
			next.append(result[j].lerp(result[j + 1], 0.25))
			next.append(result[j].lerp(result[j + 1], 0.75))
		next.append(result[result.size() - 1])
		result = next
	return result
