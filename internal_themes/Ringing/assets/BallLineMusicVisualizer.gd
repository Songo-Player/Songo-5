extends Control
class_name BallLineMusicVisualizer

const BallTexture = preload("res://internal_themes/Ringing/assets/ball_texture.gd")

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

# The engine's spectrum, which measures like Godot's spectrum analyzer
# (see SongoPlayer.get_spectrum)
var spectrum
var energy := 0.0
var offset := 0.0 # scroll distance, wrapped to ball_spacing
var visualizer_mode := "visualizer"

# The column is drawn once on this and scrolled by moving it. It has to be a
# Node2D, since the parent container controls this Control's position.
var _column: Node2D

func _ready() -> void:
	spectrum = SongoPlayer.get_spectrum()
	_update_visualizer_mode()
	ThemeManager.theme_settings_updated.connect(_update_visualizer_mode)

	_column = Node2D.new()
	_column.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_column.draw.connect(_draw_column)
	add_child(_column)

	get_parent().resized.connect(_column.queue_redraw)

func _update_visualizer_mode() -> void:
	visualizer_mode = ThemeManager.settings.get("line_dots_mode", "visualizer")

func _process(delta: float) -> void:
	if not is_inside_tree(): return
	if visualizer_mode == "static":
		return
	if not spectrum:
		return
	var target_energy := 0.0
	if visualizer_mode == "visualizer":
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
		target_energy = clamp((linear_to_db(magnitude) + 60) / 60, 0.0, 1.0)
		if not SongoPlayer.is_playing():
			target_energy = 0.0
	energy = lerp(energy, target_energy, smoothing)
	var speed = lerp(min_speed, max_speed, energy)
	# Dots repeat every ball_spacing, so wrapping there loops seamlessly forever
	offset = fposmod(offset + speed * delta, ball_spacing)
	if DeviceOS.sleeping == false:
		_column.position.y = -offset

func _draw_column() -> void:
	var size = get_parent().size
	var center = size * 0.5
	# One spacing of extra dots at the bottom, for the column to scroll up into
	var ball_count = int(ceil(size.y / ball_spacing)) + 3
	var first_y = fposmod(center.y, ball_spacing) - ball_spacing
	for i in range(ball_count):
		var pos = Vector2(center.x, first_y + i * ball_spacing)
		BallTexture.draw(_column, pos, ball_radius, ball_color)
