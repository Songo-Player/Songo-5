extends Node

signal started_new_song(mp3_record)
signal updated_repeat()
signal music_started
signal music_stopped

enum MODE {
	LINEAR,
	SHUFFLE
}

var ffmpeg_audio_playback: FFmpegAudioPlaybackV4
var songo_settings = SongoSettings.get_instance()
var music_files = [MusicRecord]

var play_index = 0
var current_song
var last_queued = 0
var play_mode: MODE = MODE.LINEAR
var repeating: bool = false
var played_from_stop: bool = true

func _ready() -> void:
	ffmpeg_audio_playback = FFmpegAudioPlaybackV4.new()
	add_child(ffmpeg_audio_playback)
	ffmpeg_audio_playback.setup()
	ffmpeg_audio_playback.stream_finished.connect(_on_finished)

	if SubsonicAudioManager:
		SubsonicAudioManager.song_started.connect(_on_subsonic_song_started)
		SubsonicAudioManager.song_ended.connect(_on_finished)

	set_vol(songo_settings.music_volume)

func _on_subsonic_song_started(_song_dict: Dictionary):
	if _is_subsonic():
		started_new_song.emit(current_song)

func _is_subsonic() -> bool:
	return current_song != null and SubsonicManager and SubsonicManager.is_subsonic_song(current_song)

func play(path: String):
	if _is_subsonic():
		SubsonicAudioManager.play()
	else:
		ffmpeg_audio_playback.play(ProjectSettings.globalize_path(path))

func play_next(): play_music_record(play_index + 1)
func play_previous(): play_music_record(play_index - 1)
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
	var queue_index = max(play_index, last_queued) + 1
	music_files.insert(queue_index, music_record)
	last_queued = queue_index

func get_current_music_record():
	return current_song

func get_current_song_path():
	return music_files[play_index]

func play_music_record(music_index: int):
	if played_from_stop:
		played_from_stop = false
		music_started.emit()

	if music_index < 0:
		music_index = music_files.size() - 1

	if not repeating:
		play_index = music_index % music_files.size()

	var music_record = music_files[play_index]
	current_song = music_record

	if _is_subsonic():
		_play_subsonic(music_record)
	else:
		if is_playing():
			ffmpeg_audio_playback.stop()
			await get_tree().process_frame
		ffmpeg_audio_playback.play(music_record.full_path)
		started_new_song.emit(music_record)

func _play_subsonic(music_record: MusicRecord):
	var sid = music_record.full_path.trim_prefix("subsonic://")
	var dict = SubsonicManager.get_song_dict(sid)
	if dict.is_empty():
		return
	SubsonicAudioManager.set_queue([dict], 0)

func get_next_mp3_record():
	if repeating:
		return music_files[play_index]
	return music_files[(play_index + 1) % music_files.size()]

func stop():
	if _is_subsonic():
		SubsonicAudioManager.stop()
	else:
		ffmpeg_audio_playback.stop()
	music_stopped.emit()
	played_from_stop = true

func _on_finished() -> void:
	play_next()

func get_playback_position():
	if _is_subsonic():
		return SubsonicAudioManager.get_position()
	return ffmpeg_audio_playback.get_actual_playback_position()

func is_playing():
	if _is_subsonic():
		return SubsonicAudioManager.playing
	return ffmpeg_audio_playback.is_playing()

func pause():
	if _is_subsonic():
		SubsonicAudioManager.pause()
	else:
		ffmpeg_audio_playback.pause()
	music_stopped.emit()

func resume():
	if _is_subsonic():
		SubsonicAudioManager.resume()
	else:
		ffmpeg_audio_playback.resume()
	music_started.emit()

func seek(pos: float):
	if _is_subsonic():
		SubsonicAudioManager.seek(pos)
	else:
		ffmpeg_audio_playback.seek(pos)

func set_vol(new_vol: float = 1.0):
	ffmpeg_audio_playback.song_player.player.volume_db = linear_to_db(new_vol)
