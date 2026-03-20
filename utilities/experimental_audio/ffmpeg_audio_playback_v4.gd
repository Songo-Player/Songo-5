extends Node
class_name FFmpegAudioPlaybackV4

# Signal emitted when the C++ module finishes draining its buffer
signal stream_finished

# Configuration
# Internal References
var song_player

# Songo settings
var songo_settings = SongoSettings.get_instance()
func _ready():
	setup()

func setup():
	song_player = FFMPEGAudio.new()
	add_child(song_player)
	song_player.player.bus = "Visualizer"
	
	song_player.generator.buffer_length = 0.2
	
	# 4. Connect Signals
	song_player.connect("finished", _on_song_finished)

func _process(_delta):
	pass

func play(path: String, seek_time: float = 0.0):
	var song_path = ProjectSettings.globalize_path(path)
	set_buffer_length_ms(songo_settings.stream_buffer_length)
	song_player.play(song_path, seek_time)

func stop():
	if song_player:
		song_player.stop()
	#await get_tree().create_timer(0.1).timeout

func pause():
	if song_player:
		song_player.pause()
		
func is_playing():
	return song_player && song_player.is_playing()
	
func resume():
	if song_player:
		song_player.resume()

func seek(seconds: float):
	if song_player:
		song_player.seek(seconds)

func get_actual_playback_position() -> float:
	if song_player:
		return song_player.get_playback_position()
	return 0.0

func set_buffer_length_ms(ms: int):
	if song_player.generator:
		song_player.generator.buffer_length = snapped(ms / 1000.0, 0.001)

func _on_song_finished():
	print("FINISHED")
	stop()
	await get_tree().process_frame
	emit_signal("stream_finished")

func _exit_tree():
	# Ensure the FFmpeg process is killed when the node is removed
	if song_player:
		song_player.stop()
