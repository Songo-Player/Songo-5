extends Node

signal started_new_song(mp3_record)
signal updated_repeat()
signal music_started
signal music_stopped

enum MODE {
	LINEAR,
	SHUFFLE
}

var ffmpeg_audio_playback: FFmpegAudioPlaybackV2
var songo_settings = SongoSettings.get_instance()
var music_files = [MusicRecord]

var play_index = 0
var current_song
var last_queued = 0
var play_mode: MODE = MODE.LINEAR
var repeating: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ffmpeg_audio_playback = FFmpegAudioPlaybackV2.new()
	add_child(ffmpeg_audio_playback)
	ffmpeg_audio_playback.setup()
	ffmpeg_audio_playback.stream_finished.connect(_on_finished)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func play(path: String):
	ffmpeg_audio_playback.play(ProjectSettings.globalize_path(path))
	
func play_next(): play_music_record(play_index + 1)
func play_previous(): play_music_record(play_index -1)
func play_from_start(): play_music_record(play_index)
	
func set_music_records(music_records: Array[MusicRecord]):
	music_files = music_records.duplicate()
	last_queued = 0

func setMode(new_mode: MODE):
	play_mode = new_mode
	if play_mode == MODE.SHUFFLE:
		music_files.shuffle()

func setRepeating(new_repeating):
	repeating = new_repeating
	updated_repeat.emit()
	
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
	if is_playing() == false:
		music_started.emit()
		#print("STARTING MUSIC")
		
	if music_index < 0: music_index = music_files.size()-1
	
	if repeating == false:
		play_index = music_index % music_files.size()
	var music_record = music_files[play_index]
	ffmpeg_audio_playback.stop()
	ffmpeg_audio_playback.play(music_record.full_path)
	current_song = music_record
	started_new_song.emit(music_record)
	
func get_next_mp3_record():
	if repeating: return music_files[play_index]
	return music_files[(play_index + 1) % music_files.size()]
	
func stop():
	ffmpeg_audio_playback.stop()
	music_stopped.emit()
	#print("MUSIC STOPPED")
	
func _on_finished() -> void:
	play_next()
	
# -------- Pass on to player ---------- #

func get_playback_position():
	return ffmpeg_audio_playback.get_actual_playback_position()
	
func is_playing():
	return ffmpeg_audio_playback.player.is_playing()
	
func pause():
	ffmpeg_audio_playback.player.stream_paused = true
	music_stopped.emit()
	#print("MUSIC PAUSED")
	
func resume():
	ffmpeg_audio_playback.player.stream_paused = false
	music_started.emit()
	print("MUSIC RESUMED")
