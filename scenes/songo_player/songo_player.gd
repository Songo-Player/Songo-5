extends AudioStreamPlayer
class_name SongoPlayer

signal started_new_song(mp3_record)

var mp3_files = [Mp3Record]
var play_index = 0
var pause_position
	
func play_next(): play_mp3(play_index + 1)
func play_previous(): play_mp3(play_index -1)
func play_from_start(): play_mp3(play_index)
	
func get_current_song_path():
	return mp3_files[play_index]

func play_mp3(mp3_index: int):
	pause_position = 0
	if mp3_index < 0: mp3_index = 0
	
	play_index = mp3_index % mp3_files.size()
	var mp3_record = mp3_files[play_index]
	var file_path = mp3_record.full_path
	var audio_stream = load_mp3_as_audio_stream(file_path)
	if audio_stream:
		stream = audio_stream
		play()
		started_new_song.emit(mp3_record)
		
func load_mp3_as_audio_stream(file_path: String) -> AudioStreamMP3:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Failed to open MP3 file: ", file_path)
		return null
	
	var audio_stream = AudioStreamMP3.new()
	audio_stream.data = file.get_buffer(file.get_length())
	file.close()
	
	return audio_stream

#func get_next_audio_stream():
#	var file_path = mp3_files[(play_index + 1) % mp3_files.size()].full_path
#	return load_mp3_as_audio_stream(file_path)
	
func get_next_mp3_record():
	return mp3_files[(play_index + 1) % mp3_files.size()]
	
func pause():
	pause_position = get_playback_position()
	stop()

func resume():
	play(pause_position)
	
func _on_finished() -> void:
	play_next()
