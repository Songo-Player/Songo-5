extends MarginContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update_nav_bar()
	Controller.page_changed.connect(_update_nav_bar)
	SongoPlayer.started_new_song.connect(_update_footer_display)
	SongoPlayer.updated_repeat.connect(_on_updated_repeat)

func _process(_delta):
	%LockIcon.visible = DeviceOS.inputs_locked
	%StayAwakeIcon.visible = DeviceOS.keep_screen_awake
	
func _update_nav_bar():
	%NavLabel.text = " > ".join(Controller.nav_label)
	visible = Controller.active_container is ThemeMainSongView

func update_play_mode_icons():
	%PlaylistProgress.visible = SongoPlayer.play_mode == SongoPlayer.MODE.LINEAR && SongoPlayer.repeating == false
	%ShuffleIcon.visible = SongoPlayer.play_mode == SongoPlayer.MODE.SHUFFLE && SongoPlayer.repeating == false
	%RepeatingIcon.visible = SongoPlayer.repeating
	
func set_next_song_title():
	var next_song = SongoPlayer.get_next_mp3_record()
	var label_string = "%s ~ %s ~ %s" % [next_song.title, next_song.artist, next_song.album]
	%NextSongTitle.text = label_string
	
func _update_footer_display(music_record):
	await get_tree().process_frame
	if Controller.active_container is ThemeMainSongView:
		%FileTypeLabel.text = music_record.file_type.to_upper()
		%PlaylistProgress.text = "%d / %d" % [SongoPlayer.play_index+1, SongoPlayer.music_files.size()]
		update_play_mode_icons()
		set_next_song_title()

func _on_updated_repeat():
	update_play_mode_icons()
	set_next_song_title()
