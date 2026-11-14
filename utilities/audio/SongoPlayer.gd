extends Node
signal started_new_song(mp3_record)
signal updated_repeat()
signal music_started
signal music_stopped
signal stream_error(message: String)
signal stream_title_changed(title: String)
## On boot, after picking up the queue an earlier Songo left playing
signal resumed_leftover_playback
enum MODE {
	LINEAR,
	SHUFFLE
}
var songo_settings = SongoSettings.get_instance()
## The play queue. A TagLibTrackList, so queueing All Songs costs 4 bytes a
## track instead of a record object each; indexing it (music_files[i]) gives
## the record. Declared Variant on purpose: GDScript refuses music_files[i] on
## a variable whose (declared or inferred) type is a native object class.
var music_files: Variant = TagLibTrackList.new()
var play_index = 0
var current_song
var last_queued = 0
var play_mode: MODE = MODE.LINEAR
var repeating: bool = false:
	set(value):
		repeating = value
		if harness: harness.repeat_one = value
var played_from_stop: bool = true
## What music_started/music_stopped last said. Follows the engine too, so it
## catches pauses from outside Songo (the Android lock screen, a headset)
var music_playing := false

# -------- Engine -------- #
## The music plays in SongoPlayerHarness (addons/songo_player_harness), outside
## Godot's audio: through its songo_bgplayer daemon on Linux, in-process on
## Android where its plugin keeps it going in the background. It moves through
## the queue and blends between songs itself. Songo keeps the queue, mirrors
## it to the engine as paths, and follows along through track_changed.
var harness: Node = null
const HARNESS_STATE_STOPPED := 0
# The song we asked the engine for, so its track_changed isn't taken for the
# queue moving on by itself
var _requested_index: int = -1
var _queue_dirty := false
var _sent_blend_time := -1.0
# Set when Songo leaves the queue playing on exit
var _handed_off := false
# Until the engine's first state after connecting, which tells us whether a
# daemon from an earlier Songo is still playing
var _checking_leftover := false

# -------- Listen tracking -------- #
# Play counts are saved in batches since saving rewrites the whole library.
const LISTEN_SAVE_DELAY_SEC := 120.0
var listen_save_timer: Timer

func _ready() -> void:
	listen_save_timer = Timer.new()
	listen_save_timer.one_shot = true
	listen_save_timer.wait_time = LISTEN_SAVE_DELAY_SEC
	listen_save_timer.timeout.connect(save_listens)
	add_child(listen_save_timer)

	harness = SongoPlayerHarness.new()
	# The daemon goes when Songo does, crashes and editor stops included,
	# unless Quit with Music tells it to stay (keep_playing_after_exit)
	harness.daemon_exits_with_app = true
	# Silent playback for debugging, eg: SONGO_AUDIO_BACKEND=null
	harness.output_backend = OS.get_environment("SONGO_AUDIO_BACKEND")
	# The ALSA device, where "default" isn't the one that shares with Godot
	# (Songo5.sh picks the sound server's on handhelds)
	harness.output_device = OS.get_environment("SONGO_AUDIO_DEVICE")
	add_child(harness)
	harness.loop_queue = true
	# Songs that won't open stop playback with an error rather than being
	# skipped, so WebRadio's failover decides what plays next
	harness.skip_failed = false
	# repeat_one waits for the engine's first state (_on_harness_state_changed),
	# so it doesn't switch off the repeat of a queue an earlier Songo left playing
	set_buffer_length_ms(songo_settings.stream_buffer_length)
	harness.track_changed.connect(_on_harness_track_changed)
	harness.state_changed.connect(_on_harness_state_changed)
	harness.engine_connection_changed.connect(func(connected): _checking_leftover = connected)
	harness.error.connect(func(message): stream_error.emit(message))
	harness.stream_title_changed.connect(func(title): stream_title_changed.emit(title))
	set_vol(songo_settings.music_volume)
	apply_equalizer_settings()
	_sync_blend_time()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_listens()
	# Android holds Songo's process loop while it's in the background, so
	# check the engine directly on coming back
	if what == NOTIFICATION_APPLICATION_RESUMED:
		_set_music_playing(harness.is_playing())
	# The daemon outlives Songo, so quitting has to stop it unless the queue
	# is being left playing
	if harness and not _handed_off and (what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE):
		harness.stop()

func _process(_delta: float) -> void:
	_sync_blend_time()

# Only called when a song plays to its end (or into the crossfade), so skips
# and manual track changes don't count.
func _count_listen(music_record) -> void:
	if music_record is not TagLibMusicRecord or is_stream_record(music_record): return
	music_record.listen_count += 1
	SongoDataResource.get_instance().listens_dirty = true
	if listen_save_timer.is_stopped(): listen_save_timer.start()

func save_listens() -> void:
	listen_save_timer.stop()
	SongoDataResource.get_instance().save_listens()

## The engine runs the same filters as Godot's AudioEffectEQ10
func apply_equalizer_settings():
	var gains := PackedFloat32Array()
	for i in range(SongoEqualizer.BAND_COUNT):
		gains.append(songo_settings.equalizer.get_band_gain(i))
	harness.eq_band_gains = gains
	harness.eq_enabled = songo_settings.use_equalizer

func _sync_blend_time():
	var blend_time: float = songo_settings.playback_blend_time
	if blend_time != _sent_blend_time:
		_sent_blend_time = blend_time
		harness.blend_time = blend_time

func play_next(): play_music_record(play_index + 1)
func play_previous(): play_music_record(play_index -1)
func play_from_start(): play_music_record(play_index)

## Copies `music_records` (an Array of records, e.g. from a plugin, or a
## TagLibTrackList) into the queue.
func set_music_records(music_records):
	music_files = TagLibTrackList.from_records(music_records)
	last_queued = 0
	if music_files.is_empty():
		play_index = 0
	_queue_changed()
## Replaces the play queue without touching the current song's playback, e.g.
## when jumping to its album. `current_index` is the current song's position in
## `music_records`. Plays on linearly, as if the song had been picked from there.
func swap_music_records_silently(music_records, current_index: int):
	set_music_records(music_records)
	play_mode = MODE.LINEAR
	play_index = clamp(current_index, 0, max(music_files.size() - 1, 0))
func setMode(new_mode: MODE):
	play_mode = new_mode
	if play_mode == MODE.SHUFFLE:
		music_files.shuffle()
		_queue_changed()
func setRepeating(new_repeating):
	repeating = new_repeating
	updated_repeat.emit()

func queue_music(music_record: TagLibMusicRecord):
	var queue_index = max(play_index, last_queued)+1
	queue_index = clamp(queue_index, 0, music_files.size())
	music_files.insert(queue_index, music_record)
	last_queued = queue_index
	_queue_changed()

func get_current_music_record():
	return current_song

func play_music_record(music_index: int):
	if music_files.is_empty(): return
	played_from_stop = false
	_set_music_playing(true)
	if music_index < 0: music_index = music_files.size()-1
	if repeating == false:
		play_index = music_index % music_files.size()
	play_index = clamp(play_index, 0, music_files.size() - 1)
	_flush_queue()
	_requested_index = play_index
	harness.play_index(play_index)
	current_song = music_files[play_index]
	started_new_song.emit(current_song)

func get_next_mp3_record():
	if music_files.is_empty(): return null
	if repeating: return music_files[play_index]
	return music_files[(play_index + 1) % music_files.size()]

func stop():
	_requested_index = -1
	harness.stop()
	_set_music_playing(false)
	played_from_stop = true

# -------- Queue mirroring ---------- #
# Batches queue changes, so building one up (or swapping queues and then
# moving play_index) sends it once
func _queue_changed():
	if _queue_dirty: return
	_queue_dirty = true
	_flush_queue.call_deferred()

func _flush_queue():
	if not _queue_dirty: return
	_queue_dirty = false
	var paths: PackedStringArray = music_files.get_paths()
	for i in range(paths.size()):
		paths[i] = ProjectSettings.globalize_path(paths[i])
	harness.replace_queue(paths, clamp(play_index, 0, max(music_files.size() - 1, 0)))

func _on_harness_track_changed(index: int, path: String):
	var requested := _requested_index != -1
	_requested_index = -1
	index = _queue_index_of(index, path)
	if index == -1: return
	if requested and index == play_index and current_song == music_files[index]:
		# The one we just started, already announced
		return
	if not requested:
		# The engine moved on by itself, at the end of the song or a blend
		_count_listen(current_song)
	play_index = index
	current_song = music_files[index]
	started_new_song.emit(current_song)

# The engine's index for a song, checked against its path in case the queue
# changed while the event was on its way
func _queue_index_of(index: int, path: String) -> int:
	if index >= 0 and index < music_files.size() \
			and ProjectSettings.globalize_path(music_files.get_path_at(index)) == path:
		return index
	var paths: PackedStringArray = music_files.get_paths()
	for i in range(paths.size()):
		if ProjectSettings.globalize_path(paths[i]) == path:
			return i
	return -1

func _on_harness_state_changed(state: int):
	if _checking_leftover:
		_checking_leftover = false
		# A daemon an earlier Songo left playing (Quit with Music). Carry on with
		# its queue, or stop it rather than play music Songo doesn't know about.
		var leftover := state != HARNESS_STATE_STOPPED and played_from_stop and current_song == null
		var adopted := leftover and _adopt_leftover_queue()
		if not adopted:
			harness.repeat_one = repeating
		if leftover and not adopted:
			harness.stop()
			return
	_set_music_playing(harness.is_playing())

func _set_music_playing(playing: bool):
	if playing == music_playing: return
	music_playing = playing
	if playing: music_started.emit()
	else: music_stopped.emit()

## Takes over the queue the engine is playing, mapped back to library records.
## The engine's snapshot on connecting fills in its queue before its state, so
## both are there by now. False when it's paused, or the song playing isn't in
## the library (eg. a web radio stream).
func _adopt_leftover_queue() -> bool:
	if not harness.is_playing(): return false
	var paths: PackedStringArray = harness.get_queue()
	var engine_index: int = harness.get_current_index()
	var records: Variant = TagLibTrackList.new()
	var current_index := -1
	for i in range(paths.size()):
		var record = M3uCollection.lookup_record(paths[i])
		if record == null: continue
		if i == engine_index: current_index = records.size()
		records.append(record)
	if current_index == -1: return false
	music_files = records
	last_queued = 0
	play_index = current_index
	current_song = records[current_index]
	played_from_stop = false
	# Keeps repeating if it was when Songo quit with the music on
	setRepeating(harness.repeat_one)
	# Songs gone from the library are dropped from the engine's queue as well
	if records.size() != paths.size(): _queue_changed()
	_set_music_playing(true)
	started_new_song.emit(current_song)
	resumed_leftover_playback.emit()
	return true

# -------- Network streams ---------- #
## Web radio and other network streams are played through the same queue as
## files, as records whose full_path is a URL.
static func is_stream_record(record) -> bool:
	return record != null && record.full_path.contains("://")

func is_current_stream() -> bool:
	return is_stream_record(current_song)

## For plugins (WebRadio): how far network streams decode ahead, so a
## stalled connection doesn't stall the music, and how long to wait on one.
## The read-ahead applies to streams started after it.
func set_stream_options(buffer_length_sec: float, network_timeout_sec: float):
	harness.stream_buffer_length = buffer_length_sec
	harness.network_timeout = network_timeout_sec

# -------- Pass on to player ---------- #
func get_playback_position():
	return harness.get_playback_position()

func is_playing():
	return harness.is_playing()

func pause():
	harness.pause()
	_set_music_playing(false)

func resume():
	harness.resume()
	_set_music_playing(true)

func seek(seconds: float):
	harness.seek(seconds)

## The engine's output buffer: how far ahead of the speaker it writes. A
## change while playing reopens the output, a short blip. Android caps it at
## what the device allows.
func set_buffer_length_ms(ms: int):
	harness.output_latency_ms = ms

## What visualizers read the spectrum from. It measures the same way as
## Godot's AudioEffectSpectrumAnalyzerInstance, with the same
## get_magnitude_for_frequency_range().
func get_spectrum():
	return harness

func set_vol(new_vol: float = 1.0):
	harness.volume = new_vol

# -------- Background playback ---------- #
## "Quit with Music": the queue is already playing in the engine's daemon, so
## leaving it playing is just not stopping it, and telling the daemon to stay
## once we've gone. Songs that won't open are skipped from here on, since
## Songo won't be around to deal with them. False if nothing is playing.
func keep_playing_after_exit() -> bool:
	if played_from_stop or music_files.is_empty(): return false
	_flush_queue()
	harness.skip_failed = true
	# The idle suppression DeviceOS turned on stays on until the music stops,
	# so the daemon turns it off as it goes. It runs the hook through sh -c.
	harness.daemon_exit_hook = DeviceOS.chai_shell_command(["set-idle-suppression", "0"])
	harness.daemon_exits_with_app = false
	_handed_off = true
	return true
