extends Node
class_name FFmpegAudioPlayback

const BYTES_PER_FRAME := 4 # s16le stereo
const READ_CHUNK := 32768

var file_path := ""
var sample_rate := 44100
var channels := 2
var pcm_path := ""
var file: FileAccess
var read_offset := 0
var playing := false
var playback: AudioStreamGeneratorPlayback
var player: AudioStreamPlayer

func _init():
	pcm_path = OS.get_user_data_dir() + "/ffmpeg_stream.pcm"

func setup():
	player = AudioStreamPlayer.new()
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	playback = player.get_stream_playback()
	add_child(player)
	
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = sample_rate
	stream.buffer_length = 0.1
	player.stream = stream
	
func play(path: String):
	file_path = path
	player.play()
	playback = player.get_stream_playback()
	start_ffmpeg_stream()
	
func start_ffmpeg_stream(seek_time: float = 0.0):
	#print("Starting FFmpeg stream from: ", file_path, " at ", seek_time, "s")
	if file:
		file.close()
		file = null
	
	_delete_pcm()
	_start_ffmpeg(seek_time)
	playing = true
	read_offset = 0
	
	# Clear any existing audio in the buffer
	if playback:
		playback.clear_buffer()
	
	# Start the audio filling process
	_fill_audio_buffer()

func _fill_audio_buffer():
	if not playing:
		return
		
	# Wait a bit for ffmpeg to create the file
	#await get_tree().create_timer(0.1).timeout
	await Engine.get_main_loop().create_timer(0.1).timeout
	
	file = FileAccess.open(pcm_path, FileAccess.READ)
	if not file:
		print("Could not open PCM file, retrying...")
		_fill_audio_buffer()
		return
	
	print("PCM file opened, starting playback")
	
	# Continuously fill the audio buffer
	while playing and file:
		var available_frames = playback.get_frames_available()
		
		if available_frames > 0:
			var frames_to_read = min(available_frames, 2048)
			var audio_data = _read_pcm_frames(frames_to_read)
			
			if audio_data.size() > 0:
				playback.push_buffer(audio_data)
			else:
				# No more data available yet, wait a bit
				#await get_tree().create_timer(0.01).timeout
				await Engine.get_main_loop().create_timer(0.1).timeout
		else:
			# Buffer is full, wait a bit
			#await get_tree().create_timer(0.01).timeout
			await Engine.get_main_loop().create_timer(0.1).timeout

func _read_pcm_frames(frame_count: int) -> PackedVector2Array:
	var result = PackedVector2Array()
	
	if not file:
		return result
	
	var file_size = file.get_length()
	if file_size <= read_offset:
		# Check if file has grown
		file_size = file.get_length()
		if file_size <= read_offset:
			return result
	
	file.seek(read_offset)
	var bytes_to_read = min(frame_count * BYTES_PER_FRAME, file_size - read_offset)
	var bytes = file.get_buffer(bytes_to_read)
	read_offset += bytes.size()
	
	for i in range(0, bytes.size(), BYTES_PER_FRAME):
		if i + 3 >= bytes.size():
			break
		var l = _int16(bytes[i], bytes[i+1]) / 32768.0
		var r = _int16(bytes[i+2], bytes[i+3]) / 32768.0
		result.append(Vector2(l, r))
	
	return result

func stop():
	playing = false
	if file:
		file.close()
		file = null
	_kill_ffmpeg()
	if player:
		player.stop()

func seek(time: float):
	# Don't stop the player, just restart the stream
	playing = false
	if file:
		file.close()
		file = null
	_kill_ffmpeg()
	
	# Wait a tiny bit for cleanup
	#await get_tree().create_timer(0.05).timeout
	await Engine.get_main_loop().create_timer(0.05).timeout
	
	start_ffmpeg_stream(time)
	
# ================= FFMPEG =================
func _start_ffmpeg(seek_time: float):
	if OS.get_name() == "Windows":
		var escaped_input = file_path.replace('"', '""')
		var escaped_output = pcm_path.replace('"', '""')
		
		var cmd_parts = ["ffmpeg"]
		if seek_time > 0:
			cmd_parts += ["-ss", str(seek_time)]
		cmd_parts += [
			"-fflags", "nobuffer",
			"-flags", "low_delay",
			"-loglevel", "quiet",
			"-nostdin",
			"-i", '"' + escaped_input + '"',
			"-f", "s16le",
			"-ac", str(channels),
			"-ar", str(sample_rate),
			'"' + escaped_output + '"'
		]
		
		var cmd = " ".join(cmd_parts)
		#print("Command: ", cmd)
		OS.execute("cmd", ["/C", cmd], [], false)
	else:
		var escaped_input = file_path.replace("'", "'\\''")
		var escaped_output = pcm_path.replace("'", "'\\''")
		
		var cmd_parts = []
		if seek_time > 0:
			cmd_parts += ["-ss", str(seek_time)]
		cmd_parts += [
			"-fflags", "nobuffer",
			"-flags", "low_delay",
			"-loglevel", "quiet",
			"-nostdin",
			"-i", "'" + escaped_input + "'",
			"-f", "s16le",
			"-ac", str(channels),
			"-ar", str(sample_rate),
			"'" + escaped_output + "'"
		]
		
		var cmd = "ffmpeg " + " ".join(cmd_parts) + " &"
		#print("Command: ", cmd)
		OS.execute("sh", ["-c", cmd], [], false)

func _kill_ffmpeg():
	if OS.get_name() == "Windows":
		OS.execute("taskkill", ["/IM", "ffmpeg.exe", "/F"], [], false)
	else:
		OS.execute("pkill", ["ffmpeg"], [], false)

func _delete_pcm():
	if FileAccess.file_exists(pcm_path):
		DirAccess.remove_absolute(pcm_path)

func _int16(lo: int, hi: int) -> int:
	var v = lo | (hi << 8)
	if v >= 32768:
		v -= 65536
	return v
