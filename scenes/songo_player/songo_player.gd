extends UniversalStreamer
class_name SongoPlayer

signal started_new_song(mp3_record)

var music_files = [MusicRecord]
var play_index = 0

func play_next(): play_music_record(play_index + 1)
func play_previous(): play_music_record(play_index -1)
func play_from_start(): play_music_record(play_index)
	
func get_current_song_path():
	return music_files[play_index]
	
func play_music_record(music_index: int):
	if music_index < 0: music_index = 0
	
	play_index = music_index % music_files.size()
	var music_record = music_files[play_index]
	stream = music_record.full_path
	play()
	started_new_song.emit(music_record)
	
func get_next_mp3_record():
	return music_files[(play_index + 1) % music_files.size()]
	
func _on_finished() -> void:
	play_next()
