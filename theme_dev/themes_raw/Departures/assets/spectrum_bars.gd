extends Control
## A bar visualizer for the boarding pass's status row, after SongoClassic's
## MusicVisualizer: log-spaced frequency bands from the engine's spectrum,
## smoothed, drawn bottom up. Bars are sized to fit whatever width the layout
## gives, over a transparent background.

const P = preload("palette.gd")

const BAR_WIDTH := 6.0
const BAR_GAP := 2.0
const MIN_HZ := 20.0
const MAX_HZ := 16000.0
const DB_FLOOR := 60.0  # energy below -60 dB draws as an empty bar
const SMOOTHING := 0.25

@export var bar_color := Color(P.DEFAULT_BOARD)
## Drawn behind each bar's full height. Transparent lets the board show through.
@export var slot_color := Color(0, 0, 0, 0)

# The engine's spectrum, which measures like Godot's spectrum analyzer
# (see SongoPlayer.get_spectrum)
var spectrum
var levels := PackedFloat32Array()

func _ready() -> void:
	spectrum = SongoPlayer.get_spectrum()

func _process(_delta: float) -> void:
	if is_visible_in_tree() and not DeviceOS.sleeping:
		queue_redraw()

func _draw() -> void:
	var count := int((size.x + BAR_GAP) / (BAR_WIDTH + BAR_GAP))
	if count <= 0: return
	if levels.size() != count:
		levels.resize(count)
		levels.fill(0.0)
	# Spread the leftover width so the bars end flush with the card's edge.
	var step := (size.x + BAR_GAP) / count
	var playing: bool = spectrum != null and SongoPlayer.is_playing()

	for i in count:
		var energy := 0.0
		if playing:
			var low := MIN_HZ * pow(MAX_HZ / MIN_HZ, float(i) / count)
			var high := MIN_HZ * pow(MAX_HZ / MIN_HZ, float(i + 1) / count)
			var magnitude: float = spectrum.get_magnitude_for_frequency_range(low, high).length()
			energy = clampf((linear_to_db(magnitude) + DB_FLOOR) / DB_FLOOR, 0.0, 1.0)
		levels[i] = lerpf(levels[i], energy, SMOOTHING)

		var x := floorf(i * step)
		var width := floorf((i + 1) * step) - x - BAR_GAP
		if slot_color.a > 0.0:
			draw_rect(Rect2(x, 0, width, size.y), slot_color)
		var height := roundf(levels[i] * size.y)
		if height >= 1.0:
			draw_rect(Rect2(x, size.y - height, width, height), bar_color)
