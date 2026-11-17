extends MarginContainer
## The now playing page as a boarding pass. The song is the destination, the
## artist the carrier and the album the route it goes via. A flight path
## between departure and arrival times shows progress, and a split-flap sign
## above the pass calls out the flight's status.

const P = preload("../assets/palette.gd")

# Every status fits the flap sign's 9 cells (shorter ones pad with blanks),
# so the visualizer beside it keeps its width as the status changes.
const LANDING_SECONDS := 20.0
const TAKEOFF_SECONDS := 8.0

var current_song_duration := 1.0
var loaded_song = null
var _status := ""
var _lyrics_connected := false

func _ready() -> void:
	update_play_mode_icons()
	%PauseButton.grab_focus()
	%Ticket.minimum_size_changed.connect(_fit_ticket)
	%Center.resized.connect(_fit_ticket)
	ThemeManager.theme_settings_updated.connect(_on_theme_settings_updated)
	_on_theme_settings_updated()
	_connect_lyrics()

func setup() -> void:
	pass

func _process(_delta: float) -> void:
	%LockIcon.visible = DeviceOS.inputs_locked
	%StayAwakeIcon.visible = DeviceOS.keep_screen_awake
	update_play_time()
	_update_status()
	if not _lyrics_connected: _connect_lyrics()

func setup_display_for(music_record: TagLibMusicRecord) -> void:
	display_play_button()
	# Printed like a real pass: long names are cut short, not scrolled.
	%SongLabel.text = music_record.title
	%ArtistLabel.text = music_record.artist
	%AlbumLabel.text = music_record.album

	if loaded_song == music_record.full_path: return
	%LyricLane.clear()

	var cover = Artwork.song_cover_texture(music_record)
	%MusicImage.visible = cover != null
	%DefaultSongImage.get_parent().visible = cover == null
	if cover: %MusicImage.texture = cover

	%FileTypeLabel.text = "WEB STREAM" if SongoPlayer.is_stream_record(music_record) else music_record.file_type.to_upper()
	loaded_song = music_record.full_path
	set_end_time(music_record)
	setup_playlist_info()

func setup_playlist_info() -> void:
	%PlaylistProgress.text = "%02d/%02d" % [SongoPlayer.play_index + 1, SongoPlayer.music_files.size()]

func update_play_mode_icons() -> void:
	%PlaylistProgress.visible = SongoPlayer.play_mode == SongoPlayer.MODE.LINEAR and not SongoPlayer.repeating
	%ShuffleIcon.visible = SongoPlayer.play_mode == SongoPlayer.MODE.SHUFFLE and not SongoPlayer.repeating
	%RepeatingIcon.visible = SongoPlayer.repeating

func set_end_time(music_record: TagLibMusicRecord) -> void:
	var length_sec: float = music_record.raw_length
	if length_sec <= 0:
		current_song_duration = -1.0
		%EndTimeLabel.text = "--:--"
		return
	current_song_duration = length_sec
	%EndTimeLabel.text = _clock(length_sec)

func update_play_time() -> void:
	if not SongoPlayer.is_playing(): return
	var position: float = SongoPlayer.get_playback_position()
	%CurrentTimeLabel.text = _clock(position)
	if current_song_duration > 0:
		%RouteLine.progress = position / current_song_duration
	else:
		# A stream never lands, so the flight just keeps circling.
		%RouteLine.progress = fmod(position, 120.0) / 120.0

func _update_status() -> void:
	var status := "IN FLIGHT"
	var position: float = SongoPlayer.get_playback_position() if SongoPlayer.is_playing() else 0.0
	if not SongoPlayer.music_playing:
		status = "HOLDING"
	elif current_song_duration <= 0:
		status = "ON AIR"
	elif current_song_duration - position < LANDING_SECONDS:
		status = "LANDING"
	elif position < TAKEOFF_SECONDS:
		status = "DEPARTED"
	if status == _status: return
	_status = status
	%StatusFlap.set_text(status)

func _clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func display_play_button() -> void:
	%PlayButton.hide()
	%PauseButton.show()
	%PauseButton.grab_focus()

func display_pause_button() -> void:
	%PauseButton.hide()
	%PlayButton.show()
	%PlayButton.grab_focus()

# The pass sits under a plain Control rather than a container, since
# containers reset their children's scale. It's scaled by the Boarding Pass
# Size setting, but never past what fits the page, then centred by hand.
func _fit_ticket() -> void:
	var natural: Vector2 = %Ticket.get_combined_minimum_size()
	%Ticket.size = natural
	var room: Vector2 = %Center.size
	var fits := minf(room.x / natural.x, room.y / natural.y) if natural.x > 0 and natural.y > 0 else 1.0
	var ticket_scale := minf(P.ticket_scale(), fits)
	%Ticket.pivot_offset = Vector2.ZERO
	%Ticket.scale = Vector2(ticket_scale, ticket_scale)
	%Ticket.position = ((room - natural * ticket_scale) / 2.0).floor()

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
	%LyricLane.show_lyric(lyric_text)

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

func _on_theme_settings_updated() -> void:
	_fit_ticket()
	%StatusFlap.refresh()
	%RouteLine.marker_color = P.accent_fill()
	# Drawn straight on the page, so these use the page's colors.
	%Visualizer.bar_color = P.accent_ink()
	%LyricLane.text_color = P.text()
	$Center/Ticket/Pass/Perforation.notch_color = P.surface()
	for node in [%Stripe, %StubStripe]:
		(node.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = P.accent_fill()
	for label in %Stripe.find_children("*", "Label", true, false) + %StubStripe.find_children("*", "Label", true, false):
		label.add_theme_color_override("font_color", P.on_accent())
	for button in [%PlayButton, %PauseButton]:
		(button.get_theme_stylebox("focus") as StyleBoxFlat).bg_color = P.accent_fill()
		button.add_theme_color_override("icon_focus_color", P.on_accent())
		button.add_theme_color_override("icon_pressed_color", P.on_accent())
