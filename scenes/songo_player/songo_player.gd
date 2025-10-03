extends AudioStreamPlayer
class_name SongoPlayer

signal started_new_song(audio_stream)

var mp3_files = []
var play_index = 0
var pause_position


func load_mp3_files_from_directory(directory_path: String):
	var dir = DirAccess.open(directory_path)
	var found_mp3s = []
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		dir.list_dir_begin()
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.get_extension().to_lower() == "mp3":
				var full_path = directory_path + "/" + file_name
				found_mp3s.append(full_path)
			file_name = dir.get_next()
			
		dir.list_dir_end()
		print("Found ", found_mp3s.size(), " MP3 files")
	else:
		print("Failed to open directory: ", directory_path)

	mp3_files = found_mp3s
	
func play_next(): play_mp3(play_index + 1)
func play_previous(): play_mp3(play_index -1)
func play_from_start(): play_mp3(play_index)
	
func play_mp3(mp3_index: int):
	pause_position = 0
	if mp3_index < 0: mp3_index = 0
	
	play_index = mp3_index % mp3_files.size()
	var file_path = mp3_files[play_index]
	var audio_stream = load_mp3_as_audio_stream(file_path)
	if audio_stream:
		#setup_display_for(audio_stream)
		stream = audio_stream
		play()
		#setup_playlist_info()
		started_new_song.emit(audio_stream)
		
func load_mp3_as_audio_stream(file_path: String) -> AudioStreamMP3:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Failed to open MP3 file: ", file_path)
		return null
	
	var audio_stream = AudioStreamMP3.new()
	audio_stream.data = file.get_buffer(file.get_length())
	file.close()
	
	return audio_stream

func get_next_audio_stream():
	var file_path = mp3_files[(play_index + 1) % mp3_files.size()]
	return load_mp3_as_audio_stream(file_path)
	
func pause():
	pause_position = get_playback_position()
	stop()

func resume():
	play(pause_position)
	
func _on_finished() -> void:
	play_next()
