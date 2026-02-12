extends Control
class_name MusicVisualizer

@export var playback_node: FFmpegAudioPlaybackV2 # Reference your FFmpeg node
@export var bar_count := 32
@export var bus_name := "Visualizer"

var spectrum: AudioEffectSpectrumAnalyzerInstance
var min_values := [] # Used for smoothing
var max_values := []


func _process(delta: float) -> void:
	if DeviceOS.sleeping == false:
		queue_redraw()
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
		# Get the analyzer instance from the bus
	var bus_index = AudioServer.get_bus_index(bus_name)
	spectrum = AudioServer.get_bus_effect_instance(bus_index, 0)
	
	min_values.resize(bar_count)
	max_values.resize(bar_count)
	min_values.fill(0.0)
	max_values.fill(0.0)
	pass # Replace with function body.

func _draw():
	if not spectrum: return
	
	# 1. Get dynamic dimensions from the container
	var container_size = get_parent().size
	var total_w = container_size.x
	var total_h = container_size.y
	
	# 2. Calculate bar width and spacing
	var spacing = 2.0
	var bar_width = (total_w / bar_count)
	
	# Frequency constants
	var min_hz = 20.0
	var max_hz = 20000.0
	
	for i in range(bar_count):
		# 3. Logarithmic Frequency Distribution
		# This spreads the bass, mids, and highs more evenly across the bars
		var hz = min_hz * pow(max_hz / min_hz, float(i + 1) / bar_count)
		var prev_hz = min_hz * pow(max_hz / min_hz, float(i) / bar_count)
		
		# 4. Sample the spectrum
		var magnitude: float = spectrum.get_magnitude_for_frequency_range(prev_hz, hz).length()
		
		# 5. Normalize and Smooth
		# Adjust -60 and 0 to change the sensitivity (db range)
		var energy = clamp((linear_to_db(magnitude) + 60) / 60, 0.0, 1.0)
		if SongoPlayerV2.is_playing() == false: energy = 0.0
		
		max_values[i] = lerp(max_values[i], energy, 0.2) # Slightly faster lerp for responsiveness
		
		# 6. Draw relative to container
		var bar_height = max_values[i] * total_h
		var x_pos = (bar_count-1 -i) * bar_width
		
		# Rect2(x, y, width, height)
		# Note: We subtract bar_height from total_h so the bars grow from the bottom UP
		var bar_rect = Rect2(
			Vector2(x_pos, total_h - bar_height), 
			Vector2(bar_width - spacing, bar_height)
		)
		
		#draw_rect(bar_rect, Color.MEDIUM_SPRING_GREEN)
		draw_rect(bar_rect, Color(0,0,0,0.45))
	
