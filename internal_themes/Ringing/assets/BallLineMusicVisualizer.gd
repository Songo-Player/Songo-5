extends Control
class_name BallLineMusicVisualizer

@export var bus_name := "Visualizer"

# Column layout
@export var ball_radius := 6.0
@export var ball_spacing := 24.0 # distance between dots, in pixels
@export var ball_color := Color("93c572")

# Spectrum slice (same convention as LineMusicVisualizer2 / RingMusicVisualizer)
@export var total_ranges := 1
@export var range_index := 0 # 0-based index

# Scroll speed range (pixels/sec, upward)
@export var min_speed := 20.0
@export var max_speed := 200.0

# Smoothing for the energy value (0-1, lower = smoother)
@export var smoothing := 0.2

var spectrum: AudioEffectSpectrumAnalyzerInstance
var energy := 0.0
var offset := 0.0 # accumulated scroll distance

func _ready() -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	spectrum = AudioServer.get_bus_effect_instance(bus_index, 0)

func _get_ball_count() -> int:
	var height = get_parent().size.y
	# +2 extra balls so the wrap-around always covers the full height with no gaps
	return int(ceil(height / ball_spacing)) + 2

func _process(delta: float) -> void:
	if not spectrum:
		return
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
	var magnitude: float = spectrum.get_magnitude_for_frequency_range(slice_min_hz, slice_max_hz).length()
	var target_energy = clamp((linear_to_db(magnitude) + 60) / 60, 0.0, 1.0)
	if not SongoPlayerV2.is_playing():
		target_energy = 0.0
	energy = lerp(energy, target_energy, smoothing)
	var speed = lerp(min_speed, max_speed, energy)
	offset += speed * delta
	if DeviceOS.sleeping == false:
		queue_redraw()

func _draw() -> void:
	var size = get_parent().size
	var center = size * 0.5
	var ball_count = _get_ball_count()
	var total_span = ball_count * ball_spacing
	for i in range(ball_count):
		var raw_y = i * ball_spacing - offset
		# Wrap around a symmetric range so dots loop seamlessly forever
		var wrapped_y = fposmod(raw_y + total_span * 0.5, total_span) - total_span * 0.5
		var pos = Vector2(center.x, center.y + wrapped_y)
		draw_circle(pos, ball_radius, ball_color)
