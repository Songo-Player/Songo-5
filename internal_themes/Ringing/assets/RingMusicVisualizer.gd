
extends Control
class_name RingMusicVisualizer

const BallTexture = preload("res://internal_themes/Ringing/assets/ball_texture.gd")

# Ring layout
@export var ball_count := 12
@export var ball_radius := 6.0
@export var ring_radius := 80.0
@export var ball_color := Color("93c572")

# Spectrum slice (same convention as LineMusicVisualizer2)
@export var total_ranges := 1
@export var range_index := 0 # 0-based index

# Spin speed range (radians/sec)
@export var min_speed := 0.5
@export var max_speed := 6.0

# Smoothing for the energy value (0-1, lower = smoother)
@export var smoothing := 0.2

# The engine's spectrum, which measures like Godot's spectrum analyzer
# (see SongoPlayer.get_spectrum)
var spectrum
var energy := 0.0
var angle := 0.0
var visualizer_mode := "visualizer"

# This visualizer's frequency slice, cached since it never changes
var slice_min_hz := 20.0
var slice_max_hz := 20000.0

# The ring is drawn once on this and spun by rotating it. It has to be a Node2D,
# since rotating a Control redraws it.
var _spinner: Node2D


func _ready() -> void:
	spectrum = SongoPlayer.get_spectrum()
	_compute_slice()
	_update_visualizer_mode()
	ThemeManager.theme_settings_updated.connect(_update_visualizer_mode)

	_spinner = Node2D.new()
	_spinner.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_spinner.draw.connect(_draw_ring)
	add_child(_spinner)

	get_parent().resized.connect(_update_layout)
	_update_layout()

func _compute_slice() -> void:
	# Full spectrum range, split in log space for proper splitting
	var log_min = log(20.0)
	var log_max = log(20000.0)
	var log_range_size = (log_max - log_min) / total_ranges

	var slice_min_log = log_min + log_range_size * range_index
	slice_min_hz = exp(slice_min_log)
	slice_max_hz = exp(slice_min_log + log_range_size)

func _update_layout() -> void:
	_spinner.position = get_parent().size * 0.5

func _update_visualizer_mode() -> void:
	visualizer_mode = ThemeManager.settings.get("ring_dots_mode", "visualizer")

func _process(delta: float) -> void:
	if not is_inside_tree(): return
	if visualizer_mode == "static":
		return
	if not spectrum:
		return

	var target_energy := 0.0
	if visualizer_mode == "visualizer":
		var magnitude: float = spectrum.get_magnitude_for_frequency_range(slice_min_hz, slice_max_hz).length()
		target_energy = clamp((linear_to_db(magnitude) + 60) / 60, 0.0, 1.0)

		if not SongoPlayer.is_playing():
			target_energy = 0.0

	energy = lerp(energy, target_energy, smoothing)

	var speed = lerp(min_speed, max_speed, energy)
	angle = fmod(angle + speed * delta, TAU)

	if DeviceOS.sleeping == false:
		_spinner.rotation = angle

func _draw_ring() -> void:
	for i in range(ball_count):
		var t = float(i) / ball_count
		var ball_angle = t * TAU
		var pos = Vector2(cos(ball_angle), sin(ball_angle)) * ring_radius
		BallTexture.draw(_spinner, pos, ball_radius, ball_color)
