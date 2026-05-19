extends Control
class_name LineMusicVisualizer

@export var playback_node: FFmpegAudioPlaybackV2

@export var point_count := 10
@export var bus_name := "Visualizer"

@export var amplitude := 0.4
@export var line_width := 3.0

# NEW: range controls
@export var total_ranges := 1
@export var range_index := 0 # 0-based index

var spectrum: AudioEffectSpectrumAnalyzerInstance
var values := []

func _ready() -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	spectrum = AudioServer.get_bus_effect_instance(bus_index, 0)
	point_count = ThemeManager.settings["visualizer_density"]
	values.resize(point_count)
	values.fill(0.0)
	ThemeManager.theme_settings_updated.connect(func():
		point_count = ThemeManager.settings["visualizer_density"]
		)
	

func _process(delta: float) -> void:
	if DeviceOS.sleeping == false:
		queue_redraw()

func _draw():
	if not spectrum:
		return
	
	if values.size() != point_count:
		values.resize(point_count)
		values.fill(0.0)

	var size = get_parent().size
	var width = size.x
	var height = size.y
	var center_y = height * 0.5

	# Full spectrum range
	var min_hz = 20.0
	var max_hz = 20000.0

	# Convert to log space for proper splitting
	var log_min = log(min_hz)
	var log_max = log(max_hz)
	var log_range_size = (log_max - log_min) / total_ranges

	# This visualizer's slice
	var slice_min_log = log_min + log_range_size * range_index
	var slice_max_log = slice_min_log + log_range_size

	var slice_min_hz = exp(slice_min_log)
	var slice_max_hz = exp(slice_max_log)

	var points: PackedVector2Array = []

	for i in range(point_count):
		var t = float(i) / (point_count - 1)
		var x = t * width

		# Lock endpoints
		if i == 0 or i == point_count - 1:
			points.append(Vector2(x, center_y))
			continue

		# Map point within this slice (log scale)
		var hz = slice_min_hz * pow(slice_max_hz / slice_min_hz, float(i + 1) / point_count)
		var prev_hz = slice_min_hz * pow(slice_max_hz / slice_min_hz, float(i) / point_count)

		var magnitude: float = spectrum.get_magnitude_for_frequency_range(prev_hz, hz).length()

		var energy = clamp((linear_to_db(magnitude) + 60) / 60, 0.0, 1.0)
		if not SongoPlayerV2.is_playing():
			energy = 0.0

		values[i] = lerp(values[i], energy, 0.2)

		var direction = 1.0 if i % 2 == 0 else -1.0
		var y_offset = values[i] * height * amplitude * direction
		var y = center_y - y_offset

		points.append(Vector2(x, y))

	var smooth = smooth_points(points, 2)
	draw_polyline(smooth, Color("93c572"), line_width, true)
	#draw_polyline(points, Color("93c572"), line_width, true)

func smooth_points(points: PackedVector2Array, iterations := 2) -> PackedVector2Array:
	var result = points

	for _i in range(iterations):
		var new_points: PackedVector2Array = []
		new_points.append(result[0])

		for j in range(result.size() - 1):
			var p0 = result[j]
			var p1 = result[j + 1]

			var q = p0.lerp(p1, 0.25)
			var r = p0.lerp(p1, 0.75)

			new_points.append(q)
			new_points.append(r)

		new_points.append(result[result.size() - 1])
		result = new_points

	return result
