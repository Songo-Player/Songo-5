extends UniversalStreamer

signal started_new_song(mp3_record)

var songo_settings = SongoSettings.get_instance()
var music_files = [MusicRecord]

var play_index = 0
var current_song
var last_queued = 0

func _ready():
	buffer_length_ms = songo_settings.stream_buffer_length
	finished.connect(_on_finished)
	
func play_next(): play_music_record(play_index + 1)
func play_previous(): play_music_record(play_index -1)
func play_from_start(): play_music_record(play_index)
	
func set_music_records(music_records: Array[MusicRecord]):
	music_files = music_records.duplicate()
	last_queued = 0
	
func queue_music(music_record: MusicRecord):
	var queue_index = max(play_index, last_queued)+1
	music_files.insert(queue_index, music_record)
	last_queued = queue_index
	
func get_current_music_record():
	return current_song
	#return music_files[play_index]
	
func get_current_song_path():
	return music_files[play_index]
	
func play_music_record(music_index: int):
	if music_index < 0: music_index = 0
	
	play_index = music_index % music_files.size()
	var music_record = music_files[play_index]
	stream = music_record.full_path
	play()
	current_song = music_record
	started_new_song.emit(music_record)
	
func get_next_mp3_record():
	return music_files[(play_index + 1) % music_files.size()]
	
func _on_finished() -> void:
	play_next()
