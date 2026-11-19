extends MarginContainer
## The now playing page as a case file. The cover is the evidence photo
## clipped to the dossier; the song is the subject, the artist a known
## associate, the album where they were last seen. A rubber stamp gives the
## case's status. The song burns down like a cigarette (a small ringed
## button beside it plays or pauses), its smoke thickening with the music,
## and lyrics (when there are any) run as subtitles.

const P = preload("../assets/palette.gd")

const CLOSING_SECONDS := 20.0
# Each case's photo is clipped on at its own slight angle (radians), picked
# from the song's path so a song always lands the same way.
const TILT_MIN := -0.075
const TILT_MAX := -0.015
const TILT_TIME := 0.45

var current_song_duration := 1.0
var loaded_song = null
var _status := ""
var _lyrics_connected := false
var _tilt := -0.045
var _tilt_tween: Tween

func _ready() -> void:
	update_play_mode_icons()
	%PauseButton.grab_focus()
	%PhotoStage.resized.connect(_place_photo)
	%SongLabel.resized.connect(_fit_song_label)
	# The CJK font is attached to the fallback chain on demand, which changes
	# how tall a title's lines are without resizing the label.
	%SongLabel.get_theme_font("font").changed.connect(_fit_song_label.call_deferred)
	_place_photo()
	ThemeManager.theme_settings_updated.connect(_apply_settings)
	_apply_settings()
	_connect_lyrics()

func setup() -> void:
	pass

func _process(_delta: float) -> void:
	%LockIcon.visible = DeviceOS.inputs_locked
	%StayAwakeIcon.visible = DeviceOS.keep_screen_awake
	update_play_time()
	_update_status()
	if not _lyrics_connected: _connect_lyrics()
	%Subtitles.visible = _has_lyrics()

func setup_display_for(music_record: TagLibMusicRecord) -> void:
	display_play_button()
	%SongLabel.text = music_record.title
	%ArtistLabel.text = music_record.artist
	%AlbumLabel.text = music_record.album
	_fit_song_label.call_deferred()

	if loaded_song == music_record.full_path: return
	%Subtitles.clear()
	%Photo.texture = Artwork.song_cover_texture(music_record)
	_tilt_to(_tilt_for(str(music_record.full_path)))
	%CaseLabel.text = "CASE No. " + P.case_number(str(music_record.full_path))
	%FileTypeLabel.text = "WIRE" if SongoPlayer.is_stream_record(music_record) else music_record.file_type.to_upper()
	loaded_song = music_record.full_path
	set_end_time(music_record)
	setup_playlist_info()
	# A new case: stamp it again even if the status reads the same.
	_status = ""

func setup_playlist_info() -> void:
	%PlaylistProgress.text = "TRACK %d OF %d" % [SongoPlayer.play_index + 1, SongoPlayer.music_files.size()]

func update_play_mode_icons() -> void:
	%PlaylistProgress.visible = SongoPlayer.play_mode == SongoPlayer.MODE.LINEAR and not SongoPlayer.repeating
	%ShuffleIcon.visible = SongoPlayer.play_mode == SongoPlayer.MODE.SHUFFLE and not SongoPlayer.repeating
	%RepeatingIcon.visible = SongoPlayer.repeating

func set_end_time(music_record: TagLibMusicRecord) -> void:
	var length_sec: float = music_record.raw_length
	if length_sec <= 0:
		current_song_duration = -1.0
		%EndTimeLabel.text = "LIVE"
		return
	current_song_duration = length_sec
	%EndTimeLabel.text = P.duration_text(length_sec)

func update_play_time() -> void:
	if not SongoPlayer.is_playing(): return
	var position: float = SongoPlayer.get_playback_position()
	%CurrentTimeLabel.text = P.duration_text(position)
	if current_song_duration > 0:
		%Cigarette.progress = position / current_song_duration
	else:
		# A stream is a chain smoker: one burns down, the next is lit.
		%Cigarette.progress = fmod(position, 300.0) / 300.0

func _update_status() -> void:
	var status := "OPEN CASE"
	var position: float = SongoPlayer.get_playback_position() if SongoPlayer.is_playing() else 0.0
	if not SongoPlayer.music_playing:
		status = "ON HOLD"
	elif current_song_duration <= 0:
		status = "WIRETAP"
	elif current_song_duration - position < CLOSING_SECONDS:
		status = "CASE CLOSED"
	if status == _status: return
	_status = status
	%Stamp.text = ""
	%Stamp.stamp(status)

# Long titles wrap onto a second line. The label's height follows its line
# count, since an autowrapping label can't size itself in a container.
func _fit_song_label() -> void:
	var label: Label = %SongLabel
	var lines := clampi(label.get_line_count(), 1, label.max_lines_visible)
	var font := label.get_theme_font("font")
	# A line as laid out can be taller than the font's own height says (CJK
	# text from the fallback font rounds up a pixel more), and a label too
	# short for a whole line draws none of it, so take the larger.
	var line_h := maxf(font.get_height(label.get_theme_font_size("font_size")), label.get_line_height())
	var height := ceilf(line_h * lines + label.get_theme_constant("line_spacing") * (lines - 1))
	if not is_equal_approx(label.custom_minimum_size.y, height):
		label.custom_minimum_size.y = height

# The photo sits in a plain Control so its tilt holds, centred in the stage.
func _place_photo() -> void:
	var stage: Control = %PhotoStage
	var photo: Control = %Photo
	photo.position = Vector2.ZERO
	photo.size = stage.size
	photo.pivot_offset = stage.size / 2.0
	if _tilt_tween == null or not _tilt_tween.is_running():
		photo.rotation = _tilt

func _tilt_for(path: String) -> float:
	var t := TILT_MIN + (TILT_MAX - TILT_MIN) * float(hash(path) & 0xFFFF) / 65535.0
	# Make sure a new case visibly lands differently from the last one.
	if absf(t - _tilt) < 0.012:
		t = _tilt + (0.02 if _tilt < (TILT_MIN + TILT_MAX) / 2.0 else -0.02)
	return t

# The photo is knocked a touch and settles at its new angle.
func _tilt_to(tilt: float) -> void:
	_tilt = tilt
	if _tilt_tween: _tilt_tween.kill()
	if not is_inside_tree():
		%Photo.rotation = tilt
		return
	_tilt_tween = create_tween()
	_tilt_tween.tween_property(%Photo, "rotation", tilt, TILT_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Only songs with lyrics on file (and lyrics turned on) keep the subtitle strip.
func _has_lyrics() -> bool:
	if not SongoSettings.get_instance().render_lyrics: return false
	var lrc_process := get_node_or_null("/root/LrcProcess")
	var lyrics = lrc_process.get("_lyrics") if lrc_process else null
	return lyrics is Array and not lyrics.is_empty()

func display_play_button() -> void:
	%PlayButton.hide()
	%PauseButton.show()
	%PauseButton.grab_focus()

func display_pause_button() -> void:
	%PauseButton.hide()
	%PlayButton.show()
	%PlayButton.grab_focus()

func _apply_settings() -> void:
	%Photo.set_monochrome(P.monochrome_art())
	%Stamp.color = P.accent_on_paper()
	%Stamp.paper_color = P.PAPER
	%Confidential.add_theme_color_override("font_color", P.accent_on_paper())
	%Cigarette.band_color = P.accent()
	(%PauseButton.get_theme_stylebox("focus") as StyleBoxFlat).border_color = P.accent()
	for button in [%PlayButton, %PauseButton]:
		button.add_theme_color_override("icon_focus_color", P.accent_ink())
		button.add_theme_color_override("icon_pressed_color", P.accent_ink())

# LrcProcess sends lyrics here instead of flashing them while this is
# connected. It's started a little after boot, so this keeps trying until it
# exists. A method (not a lambda) is connected so Godot drops the connection
# when this scene is freed, e.g. on a theme switch, and lyrics go back to
# the default display.
func _connect_lyrics() -> void:
	var lrc_process := get_node_or_null("/root/LrcProcess")
	if lrc_process == null: return
	if not lrc_process.display_lyric.is_connected(_on_display_lyric):
		lrc_process.display_lyric.connect(_on_display_lyric)
	_lyrics_connected = true

func _on_display_lyric(lyric_text: String) -> void:
	%Subtitles.show_lyric(lyric_text)

##############################
#           SIGNALS          #
##############################

func _on_play_button_pressed() -> void:
	SongoPlayer.resume()
	display_play_button()

func _on_pause_button_pressed() -> void:
	SongoPlayer.pause()
	display_pause_button()

func _on_tree_entered() -> void:
	SongoPlayer.updated_repeat.connect(_on_updated_repeat)
	await get_tree().process_frame
	update_play_mode_icons()

func _on_tree_exited() -> void:
	SongoPlayer.updated_repeat.disconnect(_on_updated_repeat)

func _on_updated_repeat() -> void:
	update_play_mode_icons()
	setup_playlist_info()
