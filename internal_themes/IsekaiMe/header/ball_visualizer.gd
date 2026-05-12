extends Control
class_name BallMusicVisualizer

@export var playback_node: FFmpegAudioPlaybackV2
@export var ball_count := 32
@export var ball_base_size := 3.0
@export var ball_color := Color(0, 0, 0, 0.45)       # Starting/minimum radius of each ball
@export var bus_name := "Visualizer"

var spectrum: AudioEffectSpectrumAnalyzerInstance
var max_values := []

func _process(delta: float) -> void:
	if DeviceOS.sleeping == false:
		queue_redraw()

func _ready() -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	spectrum = AudioServer.get_bus_effect_instance(bus_index, 0)

	max_values.resize(ball_count)
	max_values.fill(0.0)
	_update_ball_color()
	ThemeManager.theme_settings_updated.connect(_update_ball_color)

func _update_ball_color():
	var background = ThemeManager.settings["background"]
	if "train" in background: 
		%BallMusicVisualizer.ball_color = Color("ff555bc8")
	if "chainsaw" in background:
		%BallMusicVisualizer.ball_color = Color("000000c8")
	if "sunset" in background:
		%BallMusicVisualizer.ball_color = Color("ffffffdc")
		
	
func _draw():
	if not spectrum: return

	var total_w = get_parent().size.x
	var total_h = get_parent().size.y
	var center_y = total_h / 2.0

	# Space balls evenly across the width
	var slot_w = total_w / ball_count

	var min_hz = 20.0
	var max_hz = 20000.0

	for i in range(ball_count):
		# Logarithmic frequency distribution
		var hz      = min_hz * pow(max_hz / min_hz, float(i + 1) / ball_count)
		var prev_hz = min_hz * pow(max_hz / min_hz, float(i)     / ball_count)

		var magnitude: float = spectrum.get_magnitude_for_frequency_range(prev_hz, hz).length()

		var energy = clamp((linear_to_db(magnitude) + 60) / 60, 0.0, 1.0)
		if SongoPlayerV2.is_playing() == false:
			energy = 0.0

		max_values[i] = lerp(max_values[i], energy, 0.2)

		# Ball centre: evenly spaced left-to-right, vertically centred
		var cx = slot_w * i + slot_w * 0.5
		var cy = center_y

		# Radius grows from ball_base_size by up to half the container height
		var radius = ball_base_size + max_values[i] * (total_h * 0.5 - ball_base_size)
		radius = max(radius, ball_base_size)   # never shrink below the base size

		draw_circle(Vector2(cx, cy), radius, ball_color)
