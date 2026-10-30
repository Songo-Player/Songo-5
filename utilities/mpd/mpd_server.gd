extends Node

# ============================================================================
#  MPD (Music Player Daemon) server for Songo-5
# ----------------------------------------------------------------------------
#  Pure-GDScript TCP server on port 6600 (configurable) speaking the MPD
#  protocol so existing MPD clients (M.A.L.P., MPDroid, ncmpcpp, mpc, ...)
#  can browse the library and control playback.
#
#  Playback is driven through the SongoPlayerV2 autoload (real audio via the
#  FFmpegPlayer GDExtension).  The library is pulled from SongoData
#  (TagLibMusicRecord) when that extension is available; otherwise it falls
#  back to a plain directory scan with ffprobe/filename metadata so the
#  server also runs on machines without the TagLib GDExtension (dev/CI).
#
#  See also the standalone reference implementation:
#  ~/github/mpd_example_godot/MPDServer.gd
# ============================================================================

const DEFAULT_PORT := 6600
const PROTOCOL_VERSION := "0.23.12"
const PLAYER_PATH := "/root/SongoPlayerV2"
const DATA_SCRIPT := "res://data/songo_data.gd"
const SETTINGS_SCRIPT := "res://data/songo_settings.gd"
const SETTINGS_SAVE_THROTTLE_MS := 3000

const ALL_CHANNELS := [
	"database", "update", "stored_playlist", "playlist",
	"player", "mixer", "output", "options", "partition",
	"sticker", "subscription", "message",
]

# --- networking -------------------------------------------------------------
var server := TCPServer.new()
var clients: Array = []
var running := false
var started_at_ms := 0
var listen_port := DEFAULT_PORT

# --- library ----------------------------------------------------------------
var library: Array = []                 # Array[Dictionary] of MPD records
var path_to_dict: Dictionary = {}       # full_path -> library dict
var scan_folders: Array = []            # dev fallback; set via set_scan_folders()
var _data = null                        # SongoData singleton (lazy)

# --- playlist ---------------------------------------------------------------
var playlist: Array = []                # Array[Dictionary]: library dict + id/pos
var playlist_version := 0               # bumped every queue mutation (status "playlist:" / plchangesposid)
var next_song_id := 0
var _playing_index := -1

# --- playback mirror --------------------------------------------------------
# With SongoPlayerV2 present these are advisory (the player is the source of
# truth); without it they act as a tiny mock so protocol behaviour still
# works in the editor/CI where the FFmpegPlayer extension may be missing.
var player = null                       # lazy, /root/SongoPlayerV2
var _settings = null
var _paused := false
var _mock_playing := false
var _mock_position := 0.0
var _volume := 50

# Position bias for pause/resume: the FFmpeg extension clears its audio
# generator buffer on pause, so after resume its reported position restarts
# near 0 even though the audio continues.  We re-bias adaptively (only if the
# reset is observed), so it is safe on platforms without the quirk too.
var _position_bias := 0.0
var _bias_pending := false
var _pending_base := 0.0
var _resume_at_ms := 0

var repeat := false
var random := false
var single := false
var consume := false
var crossfade := 0

# --- idle + misc ------------------------------------------------------------
var channel_events: Dictionary = {}     # channel -> monotonically increasing counter
var db_update_unix := 0
var _last_settings_save_ms := 0

var enabled_tagtypes: Array = [
	"Artist", "Album", "AlbumArtist", "Title", "Track", "Name",
	"Genre", "Date", "Composer", "Disc",
]


# ============================================================================
#  Lifecycle
# ============================================================================

func _ready() -> void:
	started_at_ms = Time.get_ticks_msec()
	_settings = _load_singleton(SETTINGS_SCRIPT)
	var env_port := OS.get_environment("SONGO_MPD_PORT")
	if env_port.is_valid_int():
		listen_port = int(env_port)
	else:
		listen_port = int(_settings_get("mpd_server_port", DEFAULT_PORT))
	scan_folders = _env_folders()
	refresh_library()
	_connect_player_signals()

	if not bool(_settings_get("mpd_server_enabled", true)):
		print("MPD: disabled via settings (mpd_server_enabled=false)")
		return
	# Bind IPv4 explicitly: on Android, Godot's default "*" listen creates an
	# IPv6-only socket which refuses IPv4 LAN clients (M.A.L.P., EUphonica).
	var err := server.listen(listen_port, "0.0.0.0")
	if err != OK:
		push_error("MPD: cannot listen on tcp/%d (err %d)" % [listen_port, err])
		return
	running = true
	print("MPD: listening on tcp/%d (protocol %s)" % [listen_port, PROTOCOL_VERSION])
	print("MPD: %d tracks in library" % library.size())


func _exit_tree() -> void:
	if server:
		server.stop()


func _load_singleton(path: String):
	var script := load(path)
	if script == null:
		return null
	# The script may have failed to compile (e.g. missing GDExtension types);
	# GDScript.get_instance() is then unavailable, so guard it.
	if script.has_method("get_instance"):
		return script.get_instance()
	return null


func _settings_get(key: String, default_value):
	if _settings == null:
		return default_value
	var v = _settings.get(key)
	return v if v != null else default_value


# ============================================================================
#  Library
# ============================================================================

func set_scan_folders(folders: Array) -> void:
	scan_folders = folders
	refresh_library()


func _env_folders() -> Array:
	var raw := OS.get_environment("SONGO_MPD_MUSIC_DIRS")
	if raw == "":
		return []
	var out: Array = []
	for part in raw.split(":"):
		if part != "":
			out.append(part)
	return out


func refresh_library() -> void:
	library.clear()
	path_to_dict.clear()
	db_update_unix = int(Time.get_unix_time_from_system())

	_data = _load_singleton(DATA_SCRIPT)
	if _data != null and _data.has_signal("import_finished") \
			and not _data.import_finished.is_connected(_on_import_finished):
		_data.import_finished.connect(_on_import_finished)
	var used_songo := false
	if _data != null and _data.get("music_records") != null:
		var records = _data.music_records
		if records.size() > 0:
			used_songo = true
			for rec in records:
				var dict := _songo_record_to_dict(rec)
				library.append(dict)
				path_to_dict[dict.full_path] = dict

	if not used_songo:
		for folder in scan_folders:
			var files: Array = []
			_collect_audio_files(str(folder), files)
			files.sort()
			for abs_path in files:
				var dict := _scan_record_to_dict(str(abs_path))
				library.append(dict)
				path_to_dict[dict.full_path] = dict

	_signal("database")
	if running:
		print("MPD: library refreshed, %d tracks" % library.size())


func _on_import_finished() -> void:
	# SongoData just finished (re)building the library in the app; re-read it
	# so MPD clients see new/changed tracks without having to issue `update`.
	refresh_library()


func _songo_roots() -> Array:
	if _data == null:
		return []
	var roots = _data.get("music_directory_paths")
	return roots if roots is Array else []


func _songo_record_to_dict(rec) -> Dictionary:
	var full := str(_rec_get(rec, "full_path", ""))
	var dict := {
		"file": _relative_uri(full, _songo_roots()),
		"full_path": full,
		"artist": _str_val(_rec_get(rec, "artist", "")),
		"album": _str_val(_rec_get(rec, "album", "")),
		"album_artist": _str_val(_rec_get(rec, "album_artist", "")),
		"title": _str_val(_rec_get(rec, "title", "")),
		"track": int(_rec_get(rec, "track", 0)),
		"date": _str_val(_rec_get(rec, "year", "")),
		"genre": _str_val(_rec_get(rec, "genre", "")),
		"duration": float(_rec_get(rec, "raw_length", 0.0)),
	}
	dict.record = rec
	return dict


func _scan_record_to_dict(abs_path: String) -> Dictionary:
	var dict := {
		"file": _relative_uri(abs_path, scan_folders),
		"full_path": abs_path,
		"artist": "Unknown Artist",
		"album": "Unknown Album",
		"album_artist": "",
		"title": abs_path.get_file().get_basename(),
		"track": 0,
		"date": "",
		"genre": "",
		"duration": 0.0,
	}
	var info := _ffprobe(abs_path)
	var fmt: Dictionary = info.get("format", {})
	var tags: Dictionary = fmt.get("tags", {})
	if tags.has("artist"):
		dict.artist = str(tags.artist)
	if tags.has("title"):
		dict.title = str(tags.title)
	if tags.has("album"):
		dict.album = str(tags.album)
	if tags.has("genre"):
		dict.genre = str(tags.genre)
	if tags.has("date"):
		dict.date = str(tags.date)
	if tags.has("track"):
		dict.track = int(str(tags.track).get_slice("/", 0))
	if fmt.has("duration"):
		dict.duration = float(fmt.duration)
	if dict.artist == "Unknown Artist":
		var parts := abs_path.get_file().get_basename().split(" - ")
		if parts.size() >= 2:
			dict.artist = parts[0].strip_edges()
			dict.title = parts[1].strip_edges()
			if parts.size() >= 3:
				dict.album = parts[2].strip_edges()
	# Scan-mode "records" are real TagLibMusicRecord objects when the GDTagLib
	# class is available, so SongoPlayerV2's started_new_song / auto-blend
	# code paths get an Object instead of a Dictionary.  Fall back to a plain
	# dict otherwise (e.g. running on a machine without the extension).
	dict.record = _make_record_from_scan(abs_path, dict)
	return dict


func _make_record_from_scan(abs_path: String, dict: Dictionary):
	var full_path := str(abs_path)
	var raw_length := float(dict.get("duration", 0.0))
	if ClassDB.class_exists("TagLibMusicRecord"):
		var rec: Object = ClassDB.instantiate("TagLibMusicRecord")
		if rec != null:
			rec.full_path = full_path
			rec.raw_length = raw_length
			rec.title = _str_val(dict.get("title", ""))
			rec.artist = _str_val(dict.get("artist", ""))
			rec.album = _str_val(dict.get("album", ""))
			rec.album_artist = _str_val(dict.get("album_artist", ""))
			rec.genre = _str_val(dict.get("genre", ""))
			rec.track = int(dict.get("track", 0))
			return rec
	return { "full_path": full_path, "raw_length": raw_length }


func _ffprobe(abs_path: String) -> Dictionary:
	var out: Array = []
	var code := OS.execute(
		"ffprobe",
		["-v", "quiet", "-print_format", "json", "-show_format", abs_path],
		out, true
	)
	if code != 0:
		return {}
	var text := ""
	for line in out:
		text += str(line) + "\n"
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


func _collect_audio_files(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name.begins_with("."):
			name = d.get_next()
			continue
		var full := dir.path_join(name)
		if d.current_is_dir():
			_collect_audio_files(full, out)
		elif _is_audio(name):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()


func _is_audio(name: String) -> bool:
	var ext := name.get_extension().to_lower()
	return ext in ["mp3", "ogg", "flac", "wav", "m4a", "aac", "opus", "wv"]


func _relative_uri(full: String, roots: Array) -> String:
	for root in roots:
		var r := str(root).rstrip("/") + "/"
		if full.begins_with(r):
			var rel := full.substr(r.length())
			if rel != "":
				return rel.replace("\\", "/")
	return full.replace("\\", "/")


func _rec_get(rec, key: String, default_value):
	if rec is Dictionary:
		return rec.get(key, default_value)
	var v = rec.get(key)
	return v if v != null else default_value


func _str_val(v) -> String:
	if v == null:
		return ""
	var s := str(v)
	return s.strip_edges()


func find_record(uri: String) -> Dictionary:
	for rec in library:
		if rec.file == uri:
			return rec
	var base := uri.get_file()
	for rec in library:
		if rec.file.get_file() == base:
			return rec
	return {}


# ============================================================================
#  Player bridge
# ============================================================================

func _player_node():
	if player == null:
		player = get_node_or_null(PLAYER_PATH)
	return player


func _connect_player_signals() -> void:
	var p = _player_node()
	if p == null:
		return
	if p.has_signal("started_new_song") and not p.started_new_song.is_connected(_on_started_new_song):
		p.started_new_song.connect(_on_started_new_song)
	if p.has_signal("music_started") and not p.music_started.is_connected(_on_music_started):
		p.music_started.connect(_on_music_started)
	if p.has_signal("music_stopped") and not p.music_stopped.is_connected(_on_music_stopped):
		p.music_stopped.connect(_on_music_stopped)


func _on_started_new_song(record) -> void:
	_paused = false
	_reset_position_bias()
	# Keep our song index in sync when the player auto-advances.
	var fp := ""
	if record is Dictionary:
		fp = str(record.get("full_path", ""))
	elif record != null:
		var v = record.get("full_path")
		if v != null:
			fp = str(v)
	if fp != "":
		var matches: Array = []
		for i in playlist.size():
			if str(playlist[i].full_path) == fp:
				matches.append(i)
		if matches.size() == 1:
			_playing_index = matches[0]
		elif matches.size() > 1:
			# Duplicate paths in the queue: assume sequential advance — take the
			# first match after the current index (wrapping to the first match),
			# so `next` keeps moving instead of snapping back to index 0.
			var chosen: int = matches[0]
			for m in matches:
				if m > _playing_index:
					chosen = m
					break
			_playing_index = chosen
	_signal("playlist")
	_signal("player")


func _on_music_started() -> void:
	_paused = false
	_mock_playing = true
	_signal("player")


func _on_music_stopped() -> void:
	_signal("player")


func _is_playing() -> bool:
	var p = _player_node()
	if p != null and p.has_method("is_playing"):
		return bool(p.call("is_playing"))
	return _mock_playing


func _playback_position() -> float:
	var p = _player_node()
	var raw := 0.0
	if p != null and p.has_method("get_playback_position"):
		raw = float(p.call("get_playback_position"))
	else:
		raw = _mock_position
	if _bias_pending:
		var since_ms := Time.get_ticks_msec() - _resume_at_ms
		if since_ms > 800:
			_bias_pending = false
			if raw < _pending_base * 0.5:
				_position_bias += _pending_base
	return raw + _position_bias


func _reset_position_bias() -> void:
	_position_bias = 0.0
	_bias_pending = false
	_pending_base = 0.0


func _current_play_index() -> int:
	var p = _player_node()
	if p != null:
		var v = p.get("play_index")
		if v != null:
			return int(v)
	return _playing_index


func _push_playlist_to_player(p) -> void:
	if p == null:
		return
	var records: Array = []
	for entry in playlist:
		records.append(entry.record)
	p.music_files = records


func _start_playback(index: int) -> void:
	if index < 0 or index >= playlist.size():
		return
	_reset_position_bias()
	var p = _player_node()
	if p != null:
		_push_playlist_to_player(p)
		p.call("play_music_record", index)
	_playing_index = index
	_mock_playing = true
	_mock_position = 0.0
	_paused = false
	_signal("playlist")
	_signal("player")


func _pause_playback() -> void:
	if _paused:
		return
	# Remember where we are: after resume the extension reports position from
	# ~0 (its buffer is cleared on pause), so we re-bias afterwards.
	_pending_base = _playback_position()
	var p = _player_node()
	if p != null and p.has_method("pause"):
		p.call("pause")
	_paused = true
	_signal("player")


func _resume_playback() -> void:
	if not _paused:
		return
	var p = _player_node()
	if p != null and p.has_method("resume"):
		p.call("resume")
	_paused = false
	_bias_pending = true
	_resume_at_ms = Time.get_ticks_msec()
	_signal("player")


func _stop_playback() -> void:
	_reset_position_bias()
	var p = _player_node()
	if p != null and p.has_method("stop"):
		p.call("stop")
	_paused = false
	_mock_playing = false
	_mock_position = 0.0
	_signal("player")


func _compute_step_index(direction: int) -> int:
	# Deterministic next/prev index, honouring random/repeat. Shared by the
	# mock stepper and the real-player path so both agree on where "next" lands.
	if playlist.is_empty():
		return -1
	var idx := _playing_index
	if idx < 0:
		idx = 0
	if random:
		return randi() % playlist.size()
	if direction > 0:
		if idx < playlist.size() - 1:
			return idx + 1
		return 0 if repeat else idx
	if idx > 0:
		return idx - 1
	return playlist.size() - 1 if repeat else idx


func _step_mock(direction: int) -> void:
	if playlist.is_empty():
		return
	_reset_position_bias()
	var idx := _compute_step_index(direction)
	if idx < 0:
		idx = 0
	_playing_index = idx
	_mock_playing = true
	_mock_position = 0.0
	_paused = false


func _set_volume(vol: int) -> void:
	_volume = clampi(vol, 0, 100)
	var p = _player_node()
	if p != null and p.has_method("set_vol"):
		p.call("set_vol", _volume / 100.0)
	if _settings != null:
		_settings.music_volume = _volume / 100.0
		_throttled_settings_save()
	_signal("mixer")


func _throttled_settings_save() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_settings_save_ms < SETTINGS_SAVE_THROTTLE_MS:
		return
	_last_settings_save_ms = now
	if _settings != null and _settings.has_method("save"):
		_settings.call("save")


func _seek_to(seconds: float) -> void:
	_reset_position_bias()
	var p = _player_node()
	if p != null:
		var playback = p.get("ffmpeg_audio_playback")
		if playback != null and playback.has_method("seek"):
			playback.call("seek", seconds)
			_signal("player")
	_mock_position = max(0.0, seconds)


# ============================================================================
#  Networking (unchanged from the standalone reference)
# ============================================================================

func _process(_delta: float) -> void:
	if not running:
		return

	while server.is_connection_available():
		var sock: StreamPeerTCP = server.take_connection()
		if sock == null:
			break
		sock.set_no_delay(true)
		var client := {
			"socket": sock,
			"buffer": "",
			"idle": false,
			"idle_channels": [],
			"idle_seen": {},
			"in_list": false,
			"list_ok": false,
			"list_buffer": [],
			"capture": null,
		}
		clients.append(client)
		_send_raw(client, "OK MPD %s" % PROTOCOL_VERSION)

	var alive: Array = []
	for client in clients:
		var sock: StreamPeerTCP = client.socket
		if sock == null or sock.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			continue

		var avail := sock.get_available_bytes()
		while avail > 0:
			var res: Array = sock.get_data(avail)
			if int(res[0]) != OK:
				break
			var bytes: PackedByteArray = res[1]
			if bytes.is_empty():
				break
			client.buffer += bytes.get_string_from_utf8()
			avail = sock.get_available_bytes()

		while true:
			var buf: String = client.buffer
			var nl := buf.find("\n")
			if nl < 0:
				break
			var line := buf.substr(0, nl).strip_edges()
			client.buffer = buf.substr(nl + 1)
			if line.is_empty():
				continue
			_handle_line(client, line)

		if client.idle and not client.idle_channels.is_empty():
			var changed: Array = []
			for ch in client.idle_channels:
				if channel_events.get(ch, 0) != client.idle_seen.get(ch, 0):
					changed.append(ch)
			if not changed.is_empty():
				client.idle = false
				for ch in changed:
					_send_raw(client, "changed: %s" % ch)
				_send_raw(client, "OK")

		if sock.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			alive.append(client)
	clients = alive


func _signal(channel: String) -> void:
	channel_events[channel] = channel_events.get(channel, 0) + 1
	if channel == "playlist":
		playlist_version += 1


func _send_raw(client: Dictionary, text: String) -> void:
	if client.get("capture") != null:
		client.capture.append(text)
		return
	var sock: StreamPeerTCP = client.socket
	if sock == null or sock.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	sock.put_data((text + "\n").to_utf8_buffer())


func _ok(client: Dictionary) -> void:
	_send_raw(client, "OK")


func _ack(client: Dictionary, code: int, index: int, message: String) -> void:
	_send_raw(client, "ACK [%d@%d] {%s} %s" % [code, index, "songo_mpd", message])


func _send_lines(client: Dictionary, lines: Array) -> void:
	for line in lines:
		_send_raw(client, str(line))
	_ok(client)


# ============================================================================
#  Command dispatch
# ============================================================================

func _handle_line(client: Dictionary, line: String) -> void:
	var tokens := _tokenize(line)
	if tokens.is_empty():
		_ok(client)
		return
	var cmd: String = str(tokens[0]).to_lower()
	var args: Array = tokens.slice(1)

	if client.get("in_list", false) and cmd != "command_list_end":
		client.list_buffer.append(line)
		return

	match cmd:
		"command_list_begin", "command_list_ok_begin":
			client.in_list = true
			client.list_ok = cmd == "command_list_ok_begin"
			client.list_buffer = []
		"command_list_end":
			_finish_command_list(client)
		"ping", "password":
			_ok(client)
		"close", "quit":
			client.socket.disconnect_from_host()
		"noidle":
			client.idle = false
			_ok(client)
		"idle":
			_cmd_idle(client, args)
		"status":
			_cmd_status(client)
		"stats":
			_cmd_stats(client)
		"currentsong":
			_cmd_currentsong(client)
		"play":
			_cmd_play(client, args, false)
		"playid":
			_cmd_play(client, args, true)
		"pause":
			_cmd_pause(client, args)
		"stop":
			_stop_playback()
			_ok(client)
		"next":
			_cmd_next_previous(client, 1)
		"previous":
			_cmd_next_previous(client, -1)
		"seek", "seekcur":
			_cmd_seek(client, args)
		"volume", "setvol":
			_cmd_volume(client, args)
		"crossfade":
			_cmd_crossfade(client, args)
		"repeat":
			repeat = args.size() > 0 and args[0] != "0"
			_sync_options()
			_signal("options")
			_ok(client)
		"random":
			random = args.size() > 0 and args[0] != "0"
			_sync_options()
			_signal("options")
			_ok(client)
		"single":
			single = args.size() > 0 and args[0] != "0"
			_signal("options")
			_ok(client)
		"consume":
			consume = args.size() > 0 and args[0] != "0"
			_signal("options")
			_ok(client)
		"clear":
			playlist.clear()
			_playing_index = -1
			_signal("playlist")
			if _player_node() != null:
				_player_node().music_files = []
			# Real MPD stops playback when the playlist is cleared.
			_stop_playback()
			_ok(client)
		"add":
			_cmd_add(client, args, false)
		"addid":
			_cmd_add(client, args, true)
		"delete":
			_cmd_delete(client, args)
		"deleteid":
			_cmd_deleteid(client, args)
		"playlistinfo":
			_cmd_playlistinfo(client)
		"playlistid":
			_cmd_playlistid(client, args)
		"plchangesposid":
			_cmd_plchangesposid(client, args)
		"move":
			_cmd_move(client, args)
		"swap":
			_cmd_swap(client, args, false)
		"swapid":
			_cmd_swap(client, args, true)
		"plchanges":
			_cmd_playlistinfo(client)
		"lsinfo":
			_cmd_lsinfo(client, args)
		"listall", "listallinfo":
			_cmd_listall(client, args)
		"list":
			_cmd_list(client, args)
		"search", "find":
			_cmd_search(client, args)
		"listfiles":
			_cmd_lsinfo(client, args)
		"update":
			refresh_library()
			_signal("database")
			_signal("update")
			_ok(client)
		"songo_theme":
			_cmd_songo_theme(client)
		"commands":
			_cmd_commands(client)
		"tagtypes":
			_cmd_tagtypes(client, args)
		"urlhandlers":
			_send_lines(client, ["http://", "https://"])
		"outputs":
			_send_lines(client, ["outputid: 0", "outputname: Default", "outputenabled: 1"])
		"decoders":
			_ok(client)
		"config":
			_ok(client)
		"listplaylists":
			_ok(client)
		_:
			_ack(client, 5, 0, "unknown command \"%s\"" % cmd)


func _sync_options() -> void:
	var p = _player_node()
	if p == null:
		return
	if p.has_method("setRepeating"):
		p.call("setRepeating", repeat)
	if p.has_method("setMode"):
		p.call("setMode", 1 if random else 0)


func _finish_command_list(client: Dictionary) -> void:
	client.in_list = false
	var out: Array = []
	var ok_list: bool = client.get("list_ok", false)
	for raw in client.list_buffer:
		client.capture = []
		_handle_line(client, raw)
		var resp: Array = client.capture
		client.capture = null
		var ack := ""
		for entry in resp:
			var line_text := str(entry)
			if line_text.begins_with("ACK"):
				ack = line_text
			elif line_text == "OK":
				continue
			else:
				out.append(line_text)
		if ack != "":
			out.append(ack)
			_send_raw(client, "\n".join(_to_strings(out)))
			return
		if ok_list:
			out.append("list_OK")
	out.append("OK")
	_send_raw(client, "\n".join(_to_strings(out)))


func _to_strings(arr: Array) -> Array:
	var result: Array = []
	for item in arr:
		result.append(str(item))
	return result


func _tokenize(line: String) -> Array:
	var tokens: Array = []
	var current := ""
	var in_quotes := false
	var escaped := false
	for i in line.length():
		var c := line[i]
		if escaped:
			current += c
			escaped = false
			continue
		if c == "\\":
			escaped = true
			continue
		if c == "\"":
			in_quotes = not in_quotes
			continue
		if (c == " " or c == "\t") and not in_quotes:
			if not current.is_empty():
				tokens.append(current)
				current = ""
			continue
		current += c
	if not current.is_empty():
		tokens.append(current)
	return tokens


# ============================================================================
#  Command handlers
# ============================================================================

func _cmd_idle(client: Dictionary, args: Array) -> void:
	client.idle = true
	client.idle_channels = []
	if args.is_empty():
		for ch in ALL_CHANNELS:
			client.idle_channels.append(ch)
	else:
		for a in args:
			client.idle_channels.append(str(a))
	client.idle_seen = {}
	for ch in client.idle_channels:
		client.idle_seen[ch] = channel_events.get(ch, 0)


func _cmd_status(client: Dictionary) -> void:
	var playing := _is_playing()
	var state := "stop"
	if _paused:
		state = "pause"
	elif playing:
		state = "play"
	var cur := _current_song_dict()
	var lines: Array = [
		"volume: %d" % _volume,
		"repeat: %d" % (1 if repeat else 0),
		"random: %d" % (1 if random else 0),
		"single: %d" % (1 if single else 0),
		"consume: %d" % (1 if consume else 0),
		"playlist: %d" % playlist_version,
		"playlistlength: %d" % playlist.size(),
		"state: %s" % state,
	]
	if state != "stop" and not cur.is_empty():
		lines.append("song: %d" % _current_entry_index())
		lines.append("songid: %d" % _current_entry_id())
		var dur := float(cur.get("duration", 0.0))
		lines.append("time: %d:%d" % [int(_playback_position()), int(dur)])
		lines.append("elapsed: %.3f" % _playback_position())
		if dur > 0.0:
			lines.append("duration: %.3f" % dur)
		lines.append("audio: 44100:16:2")
	if crossfade > 0:
		lines.append("xfade: %d" % crossfade)
	_send_lines(client, lines)


func _cmd_stats(client: Dictionary) -> void:
	var artists: Dictionary = {}
	var albums: Dictionary = {}
	var db_playtime := 0
	for rec in library:
		artists[rec.artist] = true
		albums[rec.album] = true
		db_playtime += int(float(rec.get("duration", 0.0)))
	var uptime := int((Time.get_ticks_msec() - started_at_ms) / 1000)
	_send_lines(client, [
		"artists: %d" % artists.size(),
		"albums: %d" % albums.size(),
		"songs: %d" % library.size(),
		"uptime: %d" % uptime,
		"playtime: %d" % uptime,
		"db_playtime: %d" % db_playtime,
		"db_update: %d" % db_update_unix,
	])


func _song_lines(rec: Dictionary, include_pos: int) -> Array:
	var lines: Array = ["file: %s" % rec.file]
	if rec.get("artist", "") != "":
		lines.append("Artist: %s" % rec.artist)
	if rec.get("album", "") != "":
		lines.append("Album: %s" % rec.album)
	if rec.get("album_artist", "") != "":
		lines.append("AlbumArtist: %s" % rec.album_artist)
	if rec.get("title", "") != "":
		lines.append("Title: %s" % rec.title)
	if int(rec.get("track", 0)) > 0:
		lines.append("Track: %d" % int(rec.track))
	if rec.get("date", "") != "":
		lines.append("Date: %s" % rec.date)
	if rec.get("genre", "") != "":
		lines.append("Genre: %s" % rec.genre)
	if float(rec.get("duration", 0.0)) > 0.0:
		lines.append("Time: %d" % int(rec.duration))
		lines.append("duration: %.3f" % float(rec.duration))
	if include_pos:
		lines.append("Pos: %d" % int(rec.pos))
		lines.append("Id: %d" % int(rec.id))
	return lines


func _current_song_dict() -> Dictionary:
	if _playing_index >= 0 and _playing_index < playlist.size():
		return playlist[_playing_index]
	return {}


func _current_entry_index() -> int:
	var cur := _current_song_dict()
	var fp := str(cur.get("full_path", ""))
	if fp != "":
		for i in playlist.size():
			if str(playlist[i].full_path) == fp:
				return i
	return _playing_index


func _current_entry_id() -> int:
	var idx := _current_entry_index()
	if idx >= 0 and idx < playlist.size():
		return int(playlist[idx].id)
	return -1


func _cmd_currentsong(client: Dictionary) -> void:
	var rec := _current_song_dict()
	if rec.is_empty():
		_send_lines(client, [])
		return
	var lines := _song_lines(rec, false)
	lines.append("Pos: %d" % _current_entry_index())
	lines.append("Id: %d" % _current_entry_id())
	_send_lines(client, lines)


func _cmd_play(client: Dictionary, args: Array, by_id: bool) -> void:
	if playlist.is_empty():
		_ok(client)
		return
	# Bare `play` follows real-MPD semantics: resume an existing pause; start
	# the currently selected song only when stopped; no-op when already playing.
	if args.is_empty():
		if _paused:
			_resume_playback()
		elif not _mock_playing and not _is_playing():
			var target := _current_play_index()
			if target < 0:
				target = 0
			_start_playback(target)
		_ok(client)
		return
	var target := _current_play_index()
	if target < 0:
		target = 0
	if args[0] == "-1":
		target = _current_play_index()
	elif by_id:
		target = _index_of_id(int(args[0]))
	else:
		target = int(args[0])
	if target < 0 or target >= playlist.size():
		_ack(client, 2, 0, "Bad song index")
		return
	_start_playback(target)
	_ok(client)


func _cmd_pause(client: Dictionary, args: Array) -> void:
	if args.is_empty():
		if _paused:
			_resume_playback()
		else:
			_pause_playback()
	elif args[0] != "0":
		_pause_playback()
	else:
		_resume_playback()
	_ok(client)


func _cmd_next_previous(client: Dictionary, direction: int) -> void:
	_reset_position_bias()
	var new_index := _compute_step_index(direction)
	if new_index >= 0 and new_index < playlist.size() and _player_node() != null:
		# Drive playback to the exact target index so the new song is
		# synchronously visible to a status query pipelined right behind this
		# command. The player's own play_next() is async — it only signals
		# started_new_song (which sets _playing_index) on a later frame, so a
		# pipelined status would otherwise still read the old index.
		_start_playback(new_index)
	else:
		_step_mock(direction)
		_signal("player")
	_ok(client)


func _cmd_seek(client: Dictionary, args: Array) -> void:
	if args.is_empty():
		_ack(client, 2, 0, "Missing argument")
		return
	var seconds := 0.0
	var value: String = str(args[0])
	if value.begins_with("+"):
		seconds = _playback_position() + float(value.substr(1))
	elif value.begins_with("-"):
		seconds = _playback_position() - float(value.substr(1))
	else:
		seconds = float(value)
	_seek_to(seconds)
	_ok(client)


func _cmd_volume(client: Dictionary, args: Array) -> void:
	if args.is_empty():
		_ack(client, 2, 0, "Missing argument")
		return
	var delta: String = str(args[0])
	if delta.begins_with("+") or delta.begins_with("-"):
		_set_volume(_volume + int(delta))
	else:
		_set_volume(int(delta))
	_ok(client)


func _cmd_crossfade(client: Dictionary, args: Array) -> void:
	if args.is_empty():
		_ack(client, 2, 0, "Missing argument")
		return
	crossfade = max(0, int(args[0]))
	if _settings != null and crossfade > 0:
		_settings.playback_blend_time = crossfade
		_throttled_settings_save()
	_signal("options")
	_ok(client)


func _cmd_add(client: Dictionary, args: Array, with_id: bool) -> void:
	if args.is_empty():
		_ack(client, 2, 0, "Missing argument")
		return
	var rec := find_record(args[0])
	if rec.is_empty():
		_ack(client, 1, 0, "No such file or directory")
		return
	var entry := rec.duplicate(true)
	entry.id = next_song_id
	entry.pos = playlist.size()
	next_song_id += 1
	playlist.append(entry)
	_signal("playlist")
	if with_id:
		_send_raw(client, "Id: %d" % entry.id)
		_ok(client)
	else:
		_ok(client)


func _cmd_delete(client: Dictionary, args: Array) -> void:
	if args.is_empty():
		_ack(client, 2, 0, "Missing argument")
		return
	var pos := int(args[0])
	if pos < 0 or pos >= playlist.size():
		_ack(client, 2, 0, "Bad song index")
		return
	playlist.remove_at(pos)
	_reindex_playlist()
	_resync_playing_index()
	_signal("playlist")
	_ok(client)


func _cmd_deleteid(client: Dictionary, args: Array) -> void:
	if args.is_empty():
		_ack(client, 2, 0, "Missing argument")
		return
	var id := int(args[0])
	for i in playlist.size():
		if playlist[i].id == id:
			playlist.remove_at(i)
			_reindex_playlist()
			_resync_playing_index()
			_signal("playlist")
			_ok(client)
			return
	_ack(client, 2, 0, "No such song")


func _reindex_playlist() -> void:
	for i in playlist.size():
		playlist[i].pos = i


func _index_of_id(id: int) -> int:
	for i in playlist.size():
		if playlist[i].id == id:
			return i
	return -1


func _cmd_playlistinfo(client: Dictionary) -> void:
	var lines: Array = []
	for rec in playlist:
		lines.append_array(_song_lines(rec, true))
	_send_lines(client, lines)


func _cmd_playlistid(client: Dictionary, args: Array) -> void:
	# "playlistid [SONGID]": the entry with that Id, or the whole queue.
	if args.is_empty():
		_cmd_playlistinfo(client)
		return
	var id := int(args[0])
	var lines: Array = []
	for rec in playlist:
		if int(rec.id) == id:
			lines.append_array(_song_lines(rec, true))
			break
	_send_lines(client, lines)


func _cmd_plchangesposid(client: Dictionary, args: Array) -> void:
	# Clients call this after an idle "playlist" event; version 0 means
	# "everything", otherwise only changes since that version. We don't keep
	# per-entry change history, so any stale version gets the full queue
	# (ids/pos are stable, so libmpdclient merges it correctly).
	var version := 0
	if not args.is_empty():
		version = int(args[0])
	if version >= playlist_version:
		_ok(client)
		return
	_cmd_playlistinfo(client)


func _cmd_move(client: Dictionary, args: Array) -> void:
	if args.size() < 2:
		_ack(client, 2, 0, "Missing arguments")
		return
	var from := int(args[0])
	var to := int(args[1])
	if from < 0 or from >= playlist.size() or to < 0 or to >= playlist.size():
		_ack(client, 2, 0, "Bad song index")
		return
	# MPD semantics: TO is the song's FINAL index (move 0 1 swaps the first two
	# songs), so insert at `to` directly — no adjustment for the removal.
	var at := to
	var entry: Dictionary = playlist[from]
	playlist.remove_at(from)
	playlist.insert(at, entry)
	_reindex_playlist()
	_resync_playing_index()
	_signal("playlist")
	_signal("player")
	_ok(client)


func _cmd_swap(client: Dictionary, args: Array, by_id: bool) -> void:
	if args.size() < 2:
		_ack(client, 2, 0, "Missing arguments")
		return
	var a := int(args[0])
	var b := int(args[1])
	if by_id:
		a = _index_of_id(a)
		b = _index_of_id(b)
	if a < 0 or b < 0 or a >= playlist.size() or b >= playlist.size() or a == b:
		_ack(client, 2, 0, "No such song" if by_id else "Bad song index")
		return
	var tmp: Dictionary = playlist[a]
	playlist[a] = playlist[b]
	playlist[b] = tmp
	_reindex_playlist()
	_resync_playing_index()
	_signal("playlist")
	_signal("player")
	_ok(client)


func _resync_playing_index() -> void:
	# After a queue edit the current song may have moved; re-derive the index
	# by full path so currentsong/status keep pointing at the same track.
	var cur := _current_song_dict()
	if cur.is_empty():
		_playing_index = -1
		return
	_playing_index = _current_entry_index()


func _cmd_lsinfo(client: Dictionary, args: Array) -> void:
	var path := "" if args.is_empty() else str(args[0]).trim_prefix("/")
	var lines: Array = []
	var seen_dirs: Dictionary = {}
	for rec in library:
		var uri: String = str(rec.file).trim_prefix("/")
		if path != "" and uri != path and not uri.begins_with(path + "/"):
			continue
		var rest := uri
		if path != "":
			rest = uri.substr(path.length()).trim_prefix("/")
		if rest.contains("/"):
			var top := rest.get_slice("/", 0)
			if top == "":
				continue
			if not seen_dirs.has(top):
				seen_dirs[top] = true
				lines.append("directory: %s" % (top if path == "" else path.path_join(top)))
			continue
		lines.append_array(_song_lines(rec, false))
	_send_lines(client, lines)


func _cmd_listall(client: Dictionary, _args: Array) -> void:
	var lines: Array = []
	for rec in library:
		lines.append_array(_song_lines(rec, false))
	_send_lines(client, lines)


func _cmd_list(client: Dictionary, args: Array) -> void:
	if args.is_empty():
		_ack(client, 2, 0, "Missing argument")
		return
	var field: String = str(args[0]).to_lower()
	var filter_field := ""
	var filter_value := ""
	if args.size() >= 3:
		filter_field = str(args[1]).to_lower()
		filter_value = str(args[2])
	var values: Dictionary = {}
	for rec in library:
		if filter_field != "" and str(rec.get(filter_field, "")).to_lower() != filter_value.to_lower():
			continue
		var value := str(rec.get(field, ""))
		if value != "":
			values[value] = true
	var keys := values.keys()
	keys.sort()
	var lines: Array = []
	for k in keys:
		lines.append("%s: %s" % [field.capitalize(), k])
	_send_lines(client, lines)


func _cmd_search(client: Dictionary, args: Array) -> void:
	if args.size() < 2:
		_ack(client, 2, 0, "Not enough arguments")
		return
	var field: String = str(args[0]).to_lower()
	var value := str(args[-1]).to_lower()
	var lines: Array = []
	for rec in library:
		var hay := str(rec.get(field, "")).to_lower()
		if hay.contains(value):
			lines.append_array(_song_lines(rec, false))
	_send_lines(client, lines)


func _cmd_tagtypes(client: Dictionary, args: Array) -> void:
	if args.is_empty():
		_send_lines(client, enabled_tagtypes)
		return
	var sub := str(args[0]).to_lower()
	match sub:
		"clear":
			enabled_tagtypes.clear()
			_ok(client)
		"add", "enable":
			for i in range(1, args.size()):
				var t := str(args[i])
				if not enabled_tagtypes.has(t):
					enabled_tagtypes.append(t)
			_ok(client)
		"remove", "disable", "delete":
			for i in range(1, args.size()):
				enabled_tagtypes.erase(str(args[i]))
			_ok(client)
		"only":
			enabled_tagtypes.clear()
			for i in range(1, args.size()):
				enabled_tagtypes.append(str(args[i]))
			_ok(client)
		_:
			_ack(client, 2, 0, "Unknown tagtypes subcommand")


func _cmd_songo_theme(client: Dictionary) -> void:
	# Songo Helper integration: expose the app's active theme and its settings
	# so a client app can mirror this device's look exactly (same theme name,
	# background color, CRT mode, ...), not just the audio side.
	var theme := {}
	if ThemeManager != null:
		theme["path"] = str(ThemeManager.theme_path)
		if ThemeManager.current_theme != null:
			theme["name"] = str(ThemeManager.current_theme.get("name", ""))
			theme["version"] = str(ThemeManager.current_theme.get("version", ""))
	if theme.get("name", "") == "":
		theme["name"] = "Songo Classic"
		theme["version"] = "0.10"
	theme["settings"] = ThemeManager.settings if ThemeManager != null else {}
	_send_raw(client, "songo_theme: %s" % JSON.stringify(theme))
	_ok(client)


func _cmd_commands(client: Dictionary) -> void:
	_send_lines(client, [
		"add", "addid", "clear", "close", "commands",
		"command_list_begin", "command_list_end", "command_list_ok_begin",
		"config", "currentsong", "delete", "deleteid", "find", "idle",
		"lsinfo", "list", "listall", "move", "next", "noidle", "outputs", "pause",
		"ping", "play", "playid", "playlistinfo", "playlistid", "plchanges",
		"plchangesposid", "previous",
		"random", "repeat", "search", "seek", "seekcur", "setvol", "single",
		"stats", "status", "stop", "swap", "swapid", "tagtypes", "update", "volume",
	])