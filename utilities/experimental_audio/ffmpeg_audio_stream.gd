extends AudioStreamGenerator
class_name FFmpegAudioStream

@export var file_path: String

var playback: FFmpegAudioPlayback

func _init():
	mix_rate = 44100.0
	buffer_length = 0.1  # 100ms buffer

func set_file(path: String):
	file_path = path

func start_playback():
	if playback:
		playback.start_ffmpeg_stream()
