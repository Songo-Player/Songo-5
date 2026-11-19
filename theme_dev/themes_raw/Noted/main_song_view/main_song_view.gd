extends MarginContainer
## The now playing page, laid out like a scrapbook page: the cover as a
## polaroid taped down on the left, and a sticky note on the right with the
## song written on it, underlined with a pencil scribble that moves with the
## music. The song's progress is highlighter along a ruler, the play button
## is circled in pencil, and lyrics are written out on the line below.

const P = preload("../assets/palette.gd")
const Squiggle = preload("../assets/squiggle.gd")

var current_song_duration := 1.0
var loaded_song = null
var _lyrics_connected := false

func _ready() -> void:
	update_play_mode_icons()
	for label in find_children("*", "Label", true, false):
		if label.material == null: label.material = Squiggle.material(0.15)
	for icon in [%ShuffleIcon, %RepeatingIcon, %LockIcon, %StayAwakeIcon]:
		icon.material = Squiggle.material(1.5)
	for button in [%PlayButton, %PauseButton]:
		button.material = Squiggle.material(1.5)
		button.focus_entered.connect(_mark_button.bind(button, true))
		button.focus_exited.connect(_mark_button.bind(button, false))
	%PauseButton.grab_focus()
	%PhotoStage.resized.connect(_place_photo)
	%SongLabel.resized.connect(_fit_song_label)
	# The CJK font is attached to the fallback chain on demand, which changes
	# how tall a title's lines are without resizing the label.
	%SongLabel.get_theme_font("font").changed.connect(_fit_song_label.call_deferred)
	_place_photo()
	_connect_lyrics()

func setup() -> void:
	pass

func _process(_delta: float) -> void:
	%LockIcon.visible = DeviceOS.inputs_locked
	%StayAwakeIcon.visible = DeviceOS.keep_screen_awake
	update_play_time()
	if not _lyrics_connected: _connect_lyrics()

func setup_display_for(music_record: TagLibMusicRecord) -> void:
	display_play_button()
	%SongLabel.text = music_record.title
	%ArtistLabel.text = "by %s" % music_record.artist
	%AlbumLabel.text = "from %s" % music_record.album
	_fit_song_label.call_deferred()

	if loaded_song == music_record.full_path: return
	%LyricWriter.clear()
	%Polaroid.show_texture(Artwork.song_cover_texture(music_record), str(music_record.album))
	# The caption makes the polaroid taller, so the tape moves to suit.
	_place_photo.call_deferred()
	%FileTypeLabel.text = "stream" if SongoPlayer.is_stream_record(music_record) else music_record.file_type.to_lower()
	loaded_song = music_record.full_path
	set_end_time(music_record)
	setup_playlist_info()

func setup_playlist_info() -> void:
	%PlaylistProgress.text = "track %d of %d" % [SongoPlayer.play_index + 1, SongoPlayer.music_files.size()]

func update_play_mode_icons() -> void:
	%PlaylistProgress.visible = SongoPlayer.play_mode == SongoPlayer.MODE.LINEAR and not SongoPlayer.repeating
	%ShuffleIcon.visible = SongoPlayer.play_mode == SongoPlayer.MODE.SHUFFLE and not SongoPlayer.repeating
	%RepeatingIcon.visible = SongoPlayer.repeating

func set_end_time(music_record: TagLibMusicRecord) -> void:
	var length_sec: float = music_record.raw_length
	if length_sec <= 0:
		current_song_duration = -1.0
		%EndTimeLabel.text = "??:??"
		return
	current_song_duration = length_sec
	%EndTimeLabel.text = _clock(length_sec)

func update_play_time() -> void:
	if not SongoPlayer.is_playing(): return
	var position: float = SongoPlayer.get_playback_position()
	%CurrentTimeLabel.text = _clock(position)
	if current_song_duration > 0:
		%Ruler.progress = position / current_song_duration
	else:
		# A stream never ends, so the highlighter just goes back and forth.
		%Ruler.progress = 0.5 + 0.5 * sin(position / 20.0)

func _clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]

# Long titles wrap onto a second line rather than scrolling. The label's
# height follows its line count (an autowrapping label can't size itself).
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

# The polaroid sits in a plain Control so its tilt holds; it's centred in
# the space left of the note, with the tape across its top edge.
func _place_photo() -> void:
	var stage: Control = %PhotoStage
	%Polaroid.size = stage.size
	%Polaroid.position = Vector2.ZERO
	var frame: Vector2 = %Polaroid.frame_size()
	var top := (stage.size.y - frame.y) / 2.0
	%Tape.size = Vector2(70, 20)
	%Tape.pivot_offset = %Tape.size / 2.0
	# Half on the photo's top edge, half off it.
	%Tape.position = Vector2(stage.size.x / 2.0 - 35.0, top - 6.0)

func _mark_button(button: Button, focused: bool) -> void:
	var loop := button.get_node("Loop")
	create_tween().tween_property(loop, "marked", 1.0 if focused else 0.0, 0.15)

func display_play_button() -> void:
	%PlayButton.hide()
	%PauseButton.show()
	%PauseButton.grab_focus()

func display_pause_button() -> void:
	%PauseButton.hide()
	%PlayButton.show()
	%PlayButton.grab_focus()

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
	%LyricWriter.show_lyric(lyric_text)

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
