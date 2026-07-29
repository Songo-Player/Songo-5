extends Node

var player: AudioStreamPlayer
var queue: Array[Dictionary] = []
var current_index: int = -1
var playing: bool = false
var current_song: Dictionary = {}

signal song_started(song: Dictionary)
signal song_ended

func _ready():
	player = AudioStreamPlayer.new()
	add_child(player)
	player.bus = &"Master"
	player.finished.connect(_on_song_finished)
	SubsonicManager.song_download_ready.connect(_on_song_ready)

func set_queue(songs: Array[Dictionary], start_index: int = 0):
	queue = songs.duplicate()
	current_index = start_index
	if queue.size() > 0:
		play()

func queue_song(song: Dictionary):
	queue.append(song)

func queue_songs(songs: Array[Dictionary]):
	queue.append_array(songs)

func play():
	if current_index < 0 or current_index >= queue.size():
		return
	current_song = queue[current_index]
	var song_id = current_song.get("id", "")
	SubsonicManager.download_song(song_id)
	_prefetch_upcoming()

func _prefetch_upcoming():
	for offset in range(1, 4):
		var idx = current_index + offset
		if idx >= queue.size():
			return
		var sid = queue[idx].get("id", "")
		if not sid.is_empty():
			SubsonicManager.download_song(sid)

func _on_song_ready(song_id: String, local_path: String):
	if current_song.get("id", "") != song_id:
		return
	var stream = _load_audio_stream(local_path)
	if stream == null:
		_skip_to_next()
		return
	player.stream = stream
	player.play()
	playing = true
	song_started.emit(current_song)
	SubsonicManager.scrobble_song(song_id)

func _load_audio_stream(path: String) -> AudioStream:
	if not FileAccess.file_exists(path):
		return null
	var data = FileAccess.get_file_as_bytes(path)
	if data.is_empty():
		return null
	var stream = AudioStreamMP3.new()
	stream.data = data
	return stream

func previous():
	if current_index > 0:
		current_index -= 1
		play()

func next():
	_skip_to_next()

func _skip_to_next():
	if current_index < queue.size() - 1:
		current_index += 1
		play()
	else:
		playing = false
		song_ended.emit()

func pause():
	player.stream_paused = true
	playing = false

func resume():
	player.stream_paused = false
	playing = true

func stop():
	player.stop()
	playing = false
	current_index = -1
	current_song = {}

func get_position() -> float:
	return player.get_playback_position()

func seek(position: float):
	player.seek(position)

func get_duration() -> float:
	if player.stream == null:
		return 0.0
	return player.stream.get_length()

func get_progress() -> float:
	var duration = get_duration()
	if duration <= 0:
		return 0.0
	return get_position() / duration

func set_volume_db(db: float):
	player.volume_db = db

func get_volume_db() -> float:
	return player.volume_db

func _on_song_finished():
	next()
