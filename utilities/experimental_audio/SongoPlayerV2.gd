extends Node
signal started_new_song(mp3_record)
signal updated_repeat()
signal music_started
signal music_stopped
enum MODE {
	LINEAR,
	SHUFFLE
}
var songo_settings = SongoSettings.get_instance()
var music_files = []
var play_index = 0
var current_song
var last_queued = 0
var play_mode: MODE = MODE.LINEAR
var repeating: bool = false
var played_from_stop: bool = true

# -------- Two persistent players, swapped instead of created/destroyed -------- #
var player_a: FFmpegAudioPlaybackV4
var player_b: FFmpegAudioPlaybackV4
var ffmpeg_audio_playback: FFmpegAudioPlaybackV4  # currently "active" player (points at a or b)
var blend_playback: FFmpegAudioPlaybackV4 = null  # currently "inactive" player, in use during a blend

var blend_target_index: int = -1
var blend_tween: Tween = null
var is_blending: bool = false
var blend_finishing: bool = false
var blend_triggered_for_current: bool = false
var blend_lead_time: float:
	get: return songo_settings.playback_blend_time
var blend_duration: float:
	get: return songo_settings.playback_blend_time

# -------- Equalizer -------- #
const EQ_BUS_NAME := "Visualizer"
var eq_effect: AudioEffectEQ10
var eq_effect_index: int = -1
var eq_bus_idx: int = -1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player_a = FFmpegAudioPlaybackV4.new()
	player_b = FFmpegAudioPlaybackV4.new()
	add_child(player_a)
	add_child(player_b)
	player_a.setup()
	player_b.setup()
	# Bind each signal to its own source so _on_finished can tell whether the
	# finish event came from the currently-active player or a stale/inactive one.
	player_a.stream_finished.connect(_on_finished.bind(player_a))
	player_b.stream_finished.connect(_on_finished.bind(player_b))
	ffmpeg_audio_playback = player_a
	set_vol(songo_settings.music_volume)
	_setup_equalizer()

func _setup_equalizer():
	eq_bus_idx = AudioServer.get_bus_index(EQ_BUS_NAME)
	if eq_bus_idx == -1:
		push_error("SongoPlayerV2: audio bus '%s' not found for equalizer" % EQ_BUS_NAME)
		return
	eq_effect = AudioEffectEQ10.new()
	AudioServer.add_bus_effect(eq_bus_idx, eq_effect)
	eq_effect_index = AudioServer.get_bus_effect_count(eq_bus_idx) - 1
	apply_equalizer_settings()

func apply_equalizer_settings():
	if not is_instance_valid(eq_effect) or eq_bus_idx == -1:
		return
	# Bypass the effect entirely when disabled, rather than relying on zeroed gains.
	AudioServer.set_bus_effect_enabled(eq_bus_idx, eq_effect_index, songo_settings.use_equalizer)
	for i in range(SongoEqualizer.BAND_COUNT):
		eq_effect.set_band_gain_db(i, songo_settings.equalizer.get_band_gain(i))

func _process(delta: float) -> void:
	_check_auto_blend()

func _check_auto_blend():
	if is_blending: return
	if blend_triggered_for_current: return
	if not is_instance_valid(ffmpeg_audio_playback): return
	if not is_playing(): return
	if current_song == null: return
	if not (current_song is Object) or not ("raw_length" in current_song): return
	if music_files.is_empty(): return
	if music_files.size() <= 1 and not repeating: return
	
	var length = current_song.raw_length
	if typeof(length) != TYPE_FLOAT and typeof(length) != TYPE_INT: return
	if length <= 0: return
	
	var pos = get_playback_position()
	if pos < 0: return
	
	var lead = min(blend_lead_time, length * 0.5)
	if length - pos <= lead:
		blend_triggered_for_current = true
		var dur = length - pos
		if dur <= 0: dur = blend_duration
		blend_play(min(blend_duration, dur))

func play(path: String):
	ffmpeg_audio_playback.play(ProjectSettings.globalize_path(path))
	
func play_next(): play_music_record(play_index + 1)
func play_previous(): play_music_record(play_index -1)
func play_from_start(): play_music_record(play_index)
	
func set_music_records(music_records: Array[TagLibMusicRecord]):
	if is_blending:
		_cancel_blend()
	music_files = music_records.duplicate()
	last_queued = 0
	if music_files.is_empty():
		play_index = 0
func setMode(new_mode: MODE):
	play_mode = new_mode
	if play_mode == MODE.SHUFFLE:
		music_files.shuffle()
func setRepeating(new_repeating):
	repeating = new_repeating
	updated_repeat.emit()
	
func queue_music(music_record: TagLibMusicRecord):
	var queue_index = max(play_index, last_queued)+1
	queue_index = clamp(queue_index, 0, music_files.size())
	music_files.insert(queue_index, music_record)
	last_queued = queue_index
	
func get_current_music_record():
	return current_song
	
func get_current_song_path():
	if music_files.is_empty(): return null
	return music_files[play_index]
	
func play_music_record(music_index: int):
	if music_files.is_empty(): return
	
	if is_blending:
		_finish_blend()
		return
	
	if played_from_stop:
		played_from_stop = false
		music_started.emit()
		
	if music_index < 0: music_index = music_files.size()-1
	
	if repeating == false:
		play_index = music_index % music_files.size()
	play_index = clamp(play_index, 0, music_files.size() - 1)
	var music_record = music_files[play_index]
	if not is_instance_valid(ffmpeg_audio_playback):
		push_error("MusicPlayer: ffmpeg_audio_playback invalid, cannot play")
		return
	if (is_playing()):
		ffmpeg_audio_playback.stop()
		await get_tree().process_frame
	ffmpeg_audio_playback.play(music_record.full_path)
	current_song = music_record
	blend_triggered_for_current = false
	started_new_song.emit(music_record)
	
func get_next_mp3_record():
	if music_files.is_empty(): return null
	if repeating: return music_files[play_index]
	return music_files[(play_index + 1) % music_files.size()]

# -------- Blending ---------- #
func blend_play(duration: float = 4.0, target_index: int = -1):
	if is_blending: return
	if music_files.is_empty(): return
	if duration <= 0: duration = 0.01
	
	var idx = target_index
	if idx == -1:
		idx = play_index if repeating else (play_index + 1) % music_files.size()
	if idx < 0 or idx >= music_files.size():
		push_warning("MusicPlayer: blend_play target_index out of range")
		return
	
	var target_record = music_files[idx]
	if target_record == null:
		push_warning("MusicPlayer: blend_play target record is null")
		return
	
	blend_target_index = idx
	
	# Use whichever persistent player isn't currently active - never create a new one.
	var incoming = player_b if ffmpeg_audio_playback == player_a else player_a
	if not is_instance_valid(incoming):
		push_error("MusicPlayer: inactive player invalid, aborting blend")
		return
	if incoming.is_playing():
		incoming.stop()
	
	blend_playback = incoming
	blend_playback.play(target_record.full_path)
	
	var target_vol = songo_settings.music_volume
	_set_playback_volume(0.0, blend_playback)
	
	is_blending = true
	
	blend_tween = create_tween()
	blend_tween.set_parallel(true)
	blend_tween.tween_method(_set_playback_volume.bind(ffmpeg_audio_playback), target_vol, 0.0, duration)
	blend_tween.tween_method(_set_playback_volume.bind(blend_playback), 0.0, target_vol, duration)
	blend_tween.chain().tween_callback(_finish_blend)

func _set_playback_volume(vol: float, playback: FFmpegAudioPlaybackV4):
	if is_instance_valid(playback):
		playback.song_player.player.volume_db = linear_to_db(max(vol, 0.0001))

func _finish_blend():
	if not is_blending: return
	if blend_finishing: return
	blend_finishing = true
	
	if blend_tween and blend_tween.is_valid():
		blend_tween.kill()
	blend_tween = null
	
	var old_playback = ffmpeg_audio_playback
	if is_instance_valid(old_playback):
		old_playback.stop()  # stop, never free - it's a persistent player, reused next time
	
	if not is_instance_valid(blend_playback):
		push_error("MusicPlayer: blend_playback invalid at finish, stopping")
		is_blending = false
		blend_finishing = false
		blend_playback = null
		music_stopped.emit()
		played_from_stop = true
		return
	
	ffmpeg_audio_playback = blend_playback
	blend_playback = null
	is_blending = false
	
	set_vol(songo_settings.music_volume)
	
	if music_files.is_empty():
		blend_finishing = false
		return
	
	if repeating == false:
		play_index = blend_target_index % music_files.size()
	play_index = clamp(play_index, 0, music_files.size() - 1)
	current_song = music_files[play_index]
	blend_triggered_for_current = false
	blend_finishing = false
	started_new_song.emit(current_song)

# Aborts an in-progress blend without promoting the blend track.
func _cancel_blend():
	if not is_blending: return
	
	if blend_tween and blend_tween.is_valid():
		blend_tween.kill()
	blend_tween = null
	
	if is_instance_valid(blend_playback):
		blend_playback.stop()  # stop, don't free
	blend_playback = null
	is_blending = false
	blend_finishing = false
	blend_triggered_for_current = false
	
	if is_instance_valid(ffmpeg_audio_playback):
		set_vol(songo_settings.music_volume)
	
func stop():
	if is_blending:
		_cancel_blend()
	if is_instance_valid(ffmpeg_audio_playback):
		ffmpeg_audio_playback.stop()
	music_stopped.emit()
	played_from_stop = true
	
func _on_finished(source: FFmpegAudioPlaybackV4) -> void:
	# Ignore finish signals from a player that isn't the currently active one
	# (e.g. a stale signal from the player we just swapped away from).
	if source != ffmpeg_audio_playback: return
	
	if is_blending:
		_finish_blend()
	else:
		play_next()
	
# -------- Pass on to player ---------- #
func get_playback_position():
	if not is_instance_valid(ffmpeg_audio_playback): return 0.0
	return ffmpeg_audio_playback.get_actual_playback_position()
	
func is_playing():
	if not is_instance_valid(ffmpeg_audio_playback): return false
	return ffmpeg_audio_playback.is_playing()
	
func pause():
	if is_instance_valid(ffmpeg_audio_playback):
		ffmpeg_audio_playback.pause()
	music_stopped.emit()
	
func resume():
	if is_instance_valid(ffmpeg_audio_playback):
		ffmpeg_audio_playback.resume()
	music_started.emit()
	
func set_vol(new_vol: float = 1.0):
	if is_instance_valid(ffmpeg_audio_playback):
		ffmpeg_audio_playback.song_player.player.volume_db = linear_to_db(new_vol)
		
