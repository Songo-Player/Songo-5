extends VBoxContainer

class_name SongPanelContainer

signal closing_container

var current_song_duration = 1
var songo_data = SongoDataResource.get_instance()
var songo_settings = SongoSettings.get_instance()
var loaded_song = null

@export var playback_node: FFmpegAudioPlaybackV2 # Reference your FFmpeg node
@export var bar_count := 32
@export var bus_name := "Visualizer"

var spectrum: AudioEffectSpectrumAnalyzerInstance
var min_values := [] # Used for smoothing
var max_values := []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%NextSongTitle.visible_characters = int(30 * (1.0/songo_settings.ui_scale))
	pass # Replace with function body.
	
func setup():
	pass
	#SongoPlayerV2.started_new_song.connect(_on_started_new_song)
	
func _draw_OLD():
	if not spectrum: return
	
	# 1. Get dynamic dimensions from the container
	var container_size = %VisualizerContainer.size
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
		max_values[i] = lerp(max_values[i], energy, 0.2) # Slightly faster lerp for responsiveness
		
		# 6. Draw relative to container
		var bar_height = max_values[i] * total_h
		var x_pos = i * bar_width
		
		# Rect2(x, y, width, height)
		# Note: We subtract bar_height from total_h so the bars grow from the bottom UP
		var bar_rect = Rect2(
			Vector2(x_pos, total_h - bar_height), 
			Vector2(bar_width - spacing, bar_height)
		)
		
		draw_rect(bar_rect, Color.MEDIUM_SPRING_GREEN)

		
func handle_input(delta: float):
	if Input.is_action_just_pressed("ui_right") || Input.is_action_just_pressed("R1"):
		SongoPlayerV2.play_next()
		display_play_button()
	
	if Input.is_action_just_pressed("ui_left") || Input.is_action_just_pressed("L1"):
		var playback_position: float = SongoPlayerV2.get_playback_position()
		display_play_button()
		if playback_position >= 3.0:
			SongoPlayerV2.play_from_start()
		else:
			SongoPlayerV2.play_previous()
	
	if Input.is_action_just_pressed("back"):
		if SongoPlayerV2.is_playing():
			Controller.save_state()
			UiHelper.show_mini_song_panel()
		else:
			SongoPlayerV2.stop()
		Controller.new_nav_back()

func render_ui():
	update_play_time()
	#queue_redraw()

func play():
	SongoPlayerV2.play_from_start()
	_on_started_new_song(SongoPlayerV2.get_current_music_record())
	%PauseButton.grab_focus()
	
		
func setup_display_for(music_record: MusicRecord):
	%EndTimeLabel.text = "00:00" # gets updated later
	%TitleLabel.set_carousel_text(music_record.title)
	%ArtistLabel.set_carousel_text(music_record.artist)
	%AlbumLabel.set_carousel_text(music_record.album)
	
	%FileTypeLabel.text = music_record.full_path.get_extension().to_upper() + " File"

	if loaded_song == music_record.full_path: return
	
	var image_texture = null
	if false && music_record.full_path.get_extension() == "mp3":
		image_texture = music_record.image_texture
		if image_texture == null:
			var image = songo_data.get_album_cover(music_record.album)
			if image != null:
				image_texture = ImageTexture.create_from_image(image)
	else:
		var image = songo_data.get_album_cover(music_record.album)
		if image != null:
			image_texture = ImageTexture.create_from_image(image)
		if image_texture == null:
			image_texture = music_record.image_texture
			
	if image_texture:
		%MusicImage.show()
		%MusicImage.texture = image_texture
	else:
		%MusicImage.hide()
		
	
	loaded_song = music_record.full_path

func set_end_time(music_record: MusicRecord):
	var length_sec: float = music_record.raw_length
	
	if length_sec < 0: 
		%EndTimeLabel.text = "00:00"
		return
		
	current_song_duration = length_sec
	var minutes: int = int(length_sec) / 60
	var seconds: int = int(length_sec) % 60
	%EndTimeLabel.text = "%d:%02d" % [minutes, seconds]
	
func update_play_time():
	if SongoPlayerV2.is_playing():
		var pos_sec: float = SongoPlayerV2.get_playback_position()
		var minutes: int = int(pos_sec) / 60
		var seconds: int = int(pos_sec) % 60
		%CurrentTimeLabel.text = "%d:%02d" % [minutes, seconds]
		var progress_ratio = pos_sec / current_song_duration
		%ProgressLine.scale.x = progress_ratio
		
func setup_playlist_info():
	var next_song = SongoPlayerV2.get_next_mp3_record()
	%NextSongTitle.text = next_song.title
	#%NextSongTitle.custom_minimum_size = get_combined_minimum_size()
	%PlaylistProgress.text = "%d / %d" % [SongoPlayerV2.play_index+1, SongoPlayerV2.music_files.size()]

func display_play_button():
	%PlayButton.hide()
	%PauseButton.show()
	%PauseButton.grab_focus()
	
func display_pause_button():
	%PauseButton.hide()
	%PlayButton.show()
	%PlayButton.grab_focus()
	
func update_play_mode_icons():
	%PlaylistProgress.visible = SongoPlayerV2.play_mode == SongoPlayerV2.MODE.LINEAR && SongoPlayerV2.repeating == false
	%ShuffleIcon.visible = SongoPlayerV2.play_mode == SongoPlayerV2.MODE.SHUFFLE && SongoPlayerV2.repeating == false
	%RepeatingIcon.visible = SongoPlayerV2.repeating
	
##############################
#           SIGNALS          #
##############################
	
func _on_started_new_song(music_record: MusicRecord):
	setup_display_for(music_record)
	set_end_time(music_record)
	setup_playlist_info()
	
func _on_play_button_pressed() -> void:
	SongoPlayerV2.resume()
	display_play_button()

func _on_pause_button_pressed() -> void:
	SongoPlayerV2.pause()
	display_pause_button()


func _on_tree_entered() -> void:
	UiHelper.hide_mini_song_panel()
	SongoPlayerV2.started_new_song.connect(_on_started_new_song)
	SongoPlayerV2.updated_repeat.connect(_on_updated_repeat)
	await get_tree().process_frame
	update_play_mode_icons()
	
	
	# Get the analyzer instance from the bus
	var bus_index = AudioServer.get_bus_index(bus_name)
	spectrum = AudioServer.get_bus_effect_instance(bus_index, 0)
	
	min_values.resize(bar_count)
	max_values.resize(bar_count)
	min_values.fill(0.0)
	max_values.fill(0.0)

	var song = SongoPlayerV2.get_current_music_record()
	if song: _on_started_new_song(song)
		#call_deferred("_on_started_new_song", song)

func _on_tree_exited() -> void:
	SongoPlayerV2.started_new_song.disconnect(_on_started_new_song)
	SongoPlayerV2.updated_repeat.disconnect(_on_updated_repeat)
	
func _on_updated_repeat():
	update_play_mode_icons()
	setup_playlist_info()
