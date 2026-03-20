extends Node
class_name FFmpegAudioPlaybackV3

const BYTES_PER_FRAME := 4 # s16le stereo
const PORT := 6000 # Local port for TCP stream

signal stream_finished

var file_path := ""
var sample_rate := 44100
var channels := 2
var playing := false

var server := TCPServer.new()
var connection: StreamPeerTCP
var playback: AudioStreamGeneratorPlayback
var player: AudioStreamPlayer
var current_stream_id := 0
var ffmpeg_pid := -1
var seek_offset: float = 0.0
# We use this to track exactly how much time has been pushed to the buffer
var frames_pushed_this_stream: int = 0
var songo_settings
	
func setup():
	player = AudioStreamPlayer.new()
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	player.bus = "Visualizer"
	add_child(player)
	songo_settings = SongoSettings.get_instance()
	
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = sample_rate
	player.stream = stream

	# Start TCP server ONCE
	var err = server.listen(PORT, "127.0.0.1")
	if err != OK:
		push_error("Failed to start TCP server on port %d" % PORT)
	else:
		print("TCP server listening on port ", PORT)

func set_buffer_length_ms(ms: int):
	if player.stream:
		player.stream.buffer_length = snapped(ms / 1000.0, 0.001)

func play(path: String, start_time: float = 0.0):
	current_stream_id += 1
	seek_offset = start_time # Store the starting point
	frames_pushed_this_stream = 0
	print("Current Stream ID: %d" % current_stream_id)
	file_path = ProjectSettings.globalize_path(path)
	
	set_buffer_length_ms(songo_settings.stream_buffer_length)
	
	player.play()
	playback = player.get_stream_playback()
	start_ffmpeg_stream(start_time, current_stream_id)

func start_ffmpeg_stream_OLD(seek_time: float = 0.0, stream_id: int = -1):
	if stream_id == -1: stream_id = current_stream_id
	# 1. Clean up previous
	stop_stream_only()
	player.stop() 
	player.play() 
	# Re-acquire the playback handle after restarting the player
	playback = player.get_stream_playback()
	
	if playback:
		playback.clear_buffer()
		
	await Engine.get_main_loop().process_frame
	
	seek_offset = seek_time
	frames_pushed_this_stream = 0
	
	# 2. Ensure Server is Listening BEFORE starting FFmpeg
	if not server.is_listening():
		var err = server.listen(PORT, "127.0.0.1")
		if err != OK:
			print("Error: Failed to listen on port ", PORT)
			return
	
	# 3. Start FFmpeg
	_start_ffmpeg(seek_time)
	playing = true
	
	if playback:
		playback.clear_buffer()
	
	# 4. Handle incoming data
	_process_tcp_stream(stream_id)

func start_ffmpeg_stream(seek_time: float = 0.0, stream_id: int = -1):
	if stream_id == -1:
		stream_id = current_stream_id

	stop_stream_only()

	player.stop()

	_start_ffmpeg(seek_time)
	playing = true

	_process_tcp_stream(stream_id)


func _process_tcp_stream_OLD(stream_id: int):
	print("Waiting for FFmpeg connection...")
	
	while playing and stream_id == current_stream_id and not server.is_connection_available():
		await get_tree().create_timer(0.1).timeout
	
	# If we switched songs while waiting, abort this old loop
	if not playing or stream_id != current_stream_id: 
		return
		
	connection = server.take_connection()
	connection.set_no_delay(true)
	
	# Added connection.poll() to keep the socket alive/updated
	while playing and stream_id == current_stream_id and connection:
		connection.poll() 
		if connection.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
			
		var available_frames = playback.get_frames_available()
		if available_frames > 0:
			var bytes_available = connection.get_available_bytes()
			if bytes_available >= BYTES_PER_FRAME:
				var to_read = min(available_frames * BYTES_PER_FRAME, bytes_available)
				to_read -= (to_read % BYTES_PER_FRAME)
				var data = connection.get_data(to_read)
				if data[0] == OK:
					#playback.push_buffer(_convert_bytes_to_frames(data[1]))
					var audio_data = _convert_bytes_to_frames(data[1])
					playback.push_buffer(audio_data)
					frames_pushed_this_stream += audio_data.size() # Keep track of frames
			else:
				await get_tree().create_timer(0.01).timeout
		else:
			await get_tree().create_timer(0.01).timeout
	
	# ONLY emit finished if we are still the active stream 
	# and the loop ended naturally (FFmpeg closed the pipe)
	var current_time = Time.get_unix_time_from_system()
	if playing and stream_id == current_stream_id:
		print("Song finished naturally.")
		# Wait for the last bit of audio in the buffer to play
		await get_tree().create_timer(player.stream.buffer_length).timeout
		
		# Final double-check before emitting
		if playing and stream_id == current_stream_id:
			stream_finished.emit()
			#stop_stream_only()
			
func _process_tcp_stream(stream_id: int) -> void:
	print("Waiting for FFmpeg connection...")

	while playing and stream_id == current_stream_id:
		if server.is_connection_available():
			break
		await get_tree().process_frame

	if not playing or stream_id != current_stream_id:
		return

	connection = server.take_connection()
	connection.set_no_delay(true)

	print("FFmpeg connected.")

	# 🔥 START PLAYER NOW
	player.play()

	# Wait one frame so playback becomes valid
	await get_tree().process_frame

	playback = player.get_stream_playback()
	if playback == null:
		push_error("Playback is still null!")
		return

	playback.clear_buffer()

	# -------- PREBUFFER --------
	var prebuffer_seconds := 0.25
	var prebuffer_frames := int(sample_rate * prebuffer_seconds)
	var frames_buffered := 0

	while playing and stream_id == current_stream_id and frames_buffered < prebuffer_frames:
		connection.poll()

		if connection.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			print("Connection dropped during prebuffer.")
			return

		var bytes_available = connection.get_available_bytes()
		if bytes_available >= BYTES_PER_FRAME:
			var to_read = bytes_available - (bytes_available % BYTES_PER_FRAME)
			var data = connection.get_data(to_read)
			if data[0] == OK:
				var frames = _convert_bytes_to_frames(data[1])
				playback.push_buffer(frames)
				frames_buffered += frames.size()
		else:
			await get_tree().process_frame

	print("Prebuffer complete.")

	# -------- MAIN LOOP --------
	while playing and stream_id == current_stream_id and connection:
		connection.poll()

		if connection.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break

		var available_frames = playback.get_frames_available()
		var bytes_available = connection.get_available_bytes()

		if available_frames > 0 and bytes_available >= BYTES_PER_FRAME:
			var max_bytes = available_frames * BYTES_PER_FRAME
			var to_read = min(max_bytes, bytes_available)
			to_read -= (to_read % BYTES_PER_FRAME)

			var data = connection.get_data(to_read)
			if data[0] == OK:
				var frames = _convert_bytes_to_frames(data[1])
				playback.push_buffer(frames)
		else:
			await get_tree().process_frame

	if playing and stream_id == current_stream_id:
		await get_tree().create_timer(player.stream.buffer_length).timeout
		if playing and stream_id == current_stream_id:
			stream_finished.emit()


func get_actual_playback_position() -> float:
	if not playing or playback == null:
		return seek_offset
	
	# How much time is currently sitting in the buffer waiting to be played?
	var buffer_fill_amount = playback.get_frames_available() # This is a bit counter-intuitive in Godot
	# A more reliable way is using the player's internal clock:
	var time_passed_in_player = player.get_playback_position()
	
	return seek_offset + time_passed_in_player
	


func _convert_bytes_to_frames(bytes: PackedByteArray) -> PackedVector2Array:
	var result = PackedVector2Array()
	# Pre-allocate size for performance
	result.resize(bytes.size() / BYTES_PER_FRAME)
	
	var idx = 0
	for i in range(0, bytes.size(), BYTES_PER_FRAME):
		# Manual decoding s16le
		# Low byte is first, High byte is second
		var l_lo = bytes[i]
		var l_hi = bytes[i+1]
		var r_lo = bytes[i+2]
		var r_hi = bytes[i+3]
		
		# Convert to signed 16-bit integer
		var l_val = l_lo | (l_hi << 8)
		if l_val >= 32768: l_val -= 65536
			
		var r_val = r_lo | (r_hi << 8)
		if r_val >= 32768: r_val -= 65536
		
		result[idx] = Vector2(l_val / 32768.0, r_val / 32768.0)
		idx += 1
		
	return result

func stop():
	print("FFmpeg Audio Playback Stopped")
	playing = false
	stop_stream_only()
	
	if player:
		player.stop()
	
func stop_stream_only():
	playing = false

	if connection:
		connection.disconnect_from_host()
		connection = null

	_kill_ffmpeg()

	
func stop_stream_for_seek():
	playing = false
	if connection:
		connection.disconnect_from_host()
		connection = null
	_kill_ffmpeg()

func seek(time: float):
	stop_stream_for_seek()
	if time < 0: time = 0
	# Small delay to ensure OS releases socket/process
	#await get_tree().create_timer(0.05).timeout 
	await Engine.get_main_loop().create_timer(0.05).timeout
	start_ffmpeg_stream(time)

func seek_to(target_time: float):
	current_stream_id += 1
	if target_time < 0.0: target_time = 0.0
	seek_offset = target_time
	start_ffmpeg_stream(target_time, current_stream_id)
	
# ================= FFMPEG =================

func _start_ffmpeg(seek_time: float):
	var output_url = "tcp://127.0.0.1:%d" % PORT
	
	# Use PackedStringArray for safer argument handling
	var args = PackedStringArray()
	args.append("-v")
	args.append("error") # Only print actual errors
	
	if seek_time > 0:
		args.append("-ss")
		args.append(str(seek_time))
	
	args.append("-i")
	args.append(file_path)
	
	args.append_array([
		"-fflags", "nobuffer",
		"-flags", "low_delay",
		"-f", "s16le",
		"-ac", str(channels),
		"-ar", str(sample_rate),
		output_url
	])

	if OS.get_name() == "Windows":
		# OS.create_process is better than OS.execute for background tasks
		ffmpeg_pid = OS.create_process("ffmpeg", args)
	else:
		var bin_path = OS.get_environment("SONGO_BINARIES_DIR")
		var cmd = "%s/ffmpeg/ffmpeg" % bin_path
		ffmpeg_pid = OS.create_process(cmd, args)
		
	if ffmpeg_pid == -1:
		print("CRITICAL ERROR: Could not start FFmpeg. Is it installed and in PATH?")

func _kill_ffmpeg():
	if ffmpeg_pid != -1:
		OS.kill(ffmpeg_pid)
		ffmpeg_pid = -1
