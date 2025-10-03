extends Control

@onready var my_label = $Label
@onready var songo_player = $SongoPlayer
@onready var sfx_player = $SfxPlayer
@onready var dark_out = %DarkOut

var music_meta_obj = MusicMeta.new()
var fade_val: float
var fade_tween = null
var initial_brightness = 64
var directory_container
var song_panel_container
var all_songs_container
var albums_container
var active_container
var songo_data = SongoDataResource.get_instance()

func _ready() -> void:
	apply_theme_color()
	Engine.physics_ticks_per_second = 0
	%CurrentOsTime.text = get_time_string()
	initial_brightness = get_os_initial_brightness()
	setup_main_menu()
	if songo_data && songo_data.music_directory_path != null:
		songo_player.load_mp3_files_from_directory(songo_data.music_directory_path)
	%VersionLabel.text = SongoDataResource.VERSION
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	
func apply_theme_color():
	var style = %MainColorPanel.get_theme_stylebox("panel").duplicate()
	style.bg_color = songo_data.theme_color
	%MainColorPanel.add_theme_stylebox_override("panel", style)
	
	var style_2 = %GradientFade.get_theme_stylebox("panel").duplicate()
	var target_color = Color(songo_data.theme_color)
	style_2.texture.gradient.colors[1] = Color(target_color, 0.0)
	style_2.texture.gradient.colors[0] = Color(target_color, 1.0)

	%GradientFade.add_theme_stylebox_override("panel", style_2)
	
func _exit_tree():
	set_backlight(initial_brightness)

func _process(delta: float) -> void:
	if Input.is_anything_pressed() && active_container is SongPanelContainer:
		$ScreenIdleTimer.start()
		wake_screen()
		
	if active_container:
		active_container.render_ui()
		active_container.handle_input(delta)
	
	if fade_tween != null:
		set_backlight(int(round(fade_val)))
	%GradientFade.visible = %MainMenu.visible == false

func set_backlight(level: int):
	OS.execute("sh", ["-c", "echo setbl > /sys/kernel/debug/dispdbg/command"])
	OS.execute("sh", ["-c", "echo lcd0 > /sys/kernel/debug/dispdbg/name"])
	OS.execute("sh", ["-c", "echo " + str(level) + " > /sys/kernel/debug/dispdbg/param"])
	OS.execute("sh", ["-c", "echo 1 > /sys/kernel/debug/dispdbg/start"])
	
func wake_screen():
	if fade_tween != null: 
		fade_tween.kill()
		fade_tween = null
	set_backlight(initial_brightness)
	
func get_os_initial_brightness():
	var output: Array = []
	var exit_code = OS.execute("sh", ["-c", "cat /sys/kernel/debug/dispdbg/param"], output)

	if exit_code == 0 and output.size() > 0:
		return int(output[0].strip_edges())
	else:
		return initial_brightness

# Path to the muOS helper that defines SET_VAR
const FUNC_SCRIPT := "/opt/muos/script/var/func.sh"

func _set_idle_inhibit(value: int) -> void:
	var cmd := "source %s && SET_VAR system idle_inhibit %d" % [FUNC_SCRIPT, value]
	OS.execute("sh", ["-c", cmd], [], true)
	
func _on_tween_fade_finished():
	fade_tween.kill()
	fade_tween = null
	set_backlight(0)
	
func _on_keep_awake_timer_timeout() -> void:
	%CurrentOsTime.text = get_time_string()
	_set_idle_inhibit(1)
	
func _on_selected_dir(path):
	songo_data.music_directory_path = path
	songo_data.save()
	songo_data.index_mp3s()
	await songo_data.import_finished
	dark_out.hide()
	#for data in songo_data.mp3_records:
	#	print(data.title)
	
	directory_container.queue_free()
	await get_tree().process_frame
	songo_player.load_mp3_files_from_directory(path)
	setup_main_menu()
	
func get_time_string() -> String:
	var now = Time.get_datetime_dict_from_system()
	var hour = str(now.hour % 12).pad_zeros(2)
	var minute = str(now.minute).pad_zeros(2)
	return "%s:%s" % [hour, minute]

func setup_main_menu():
	%MainMenu.show()
	active_container = null
	await get_tree().process_frame
	%AllSongsMenuItem.get_child(0).grab_focus()
	%NavLabel.text = " > ".join(["Main Menu"])
	
func _on_screen_idle_timer_timeout() -> void:
	if active_container is not SongPanelContainer:
		$ScreenIdleTimer.stop()
		return
	fade_tween = create_tween()
	fade_val = initial_brightness
	fade_tween.tween_property(self, "fade_val", 0.0, 2.0) # fade over 2 seconds
	fade_tween.finished.connect(Callable(self, "_on_tween_fade_finished"))

func _on_settings_menu_button_pressed() -> void:
	sfx_player.play_accept_sfx()
	%MainMenu.hide()
	directory_container = load("res://scenes/directory_container/directory_container.tscn").instantiate()
	directory_container.setup(dark_out)
	directory_container.selected_dir.connect(_on_selected_dir)
	directory_container.closing_container.connect(_back_to_main_menu)
	%ContentBody.add_child(directory_container)
	active_container = directory_container
	%NavLabel.text = " > ".join(["Main Menu", "Settings", "Directories"])


func _on_all_songs_menu_button_pressed() -> void:
	sfx_player.play_accept_sfx()
	if songo_player.mp3_files.size() == 0: return
	%MainMenu.hide()
	all_songs_container = load("res://scenes/all_songs_container/all_songs_container.tscn").instantiate()
	all_songs_container.setup(songo_player, sfx_player)
	%ContentBody.add_child(all_songs_container)
	%NavLabel.text = " > ".join(["Main Menu", "All Songs"])
	active_container = all_songs_container
	all_songs_container.closing_container.connect(_back_to_main_menu)
	all_songs_container.opening_song_panel.connect(_on_opening_song_panel_from_all_songs)

func _on_opening_song_panel_from_all_songs(play_type):
	sfx_player.play_accept_sfx()
	$ScreenIdleTimer.start()
	all_songs_container.queue_free()
	song_panel_container = load("res://scenes/song_panel_container/song_panel_container.tscn").instantiate()
	song_panel_container.setup(songo_player)
	%ContentBody.add_child(song_panel_container)
	song_panel_container.closing_container.connect(func():
		song_panel_container.queue_free()
		_on_all_songs_menu_button_pressed()
		)
	active_container = song_panel_container
	song_panel_container.play()
	%NavLabel.text = " > ".join(["Main Menu", "All Songs", play_type])

func _back_to_main_menu():
	sfx_player.play_back_sfx()
	active_container.queue_free()
	setup_main_menu()
	wake_screen()

func _on_exit_menu_button_pressed() -> void:
	sfx_player.play_accept_sfx()
	dark_out.show()
	%ExitingOverlay.show()
	await get_tree().process_frame
	get_tree().quit()

func _on_focus_changed(thing):
	sfx_player.play_nav_sfx()

func _on_album_menu_button_pressed() -> void:
	sfx_player.play_accept_sfx()
	if songo_data.albums.size() == 0: return
	%MainMenu.hide()
	albums_container = load("res://scenes/albums_container/albums_container.tscn").instantiate()
	albums_container.setup(songo_player)
	%ContentBody.add_child(albums_container)
	%NavLabel.text = " > ".join(["Main Menu", "Albums"])
	active_container = albums_container
	albums_container.closing_container.connect(_back_to_main_menu)
	#all_songs_container.opening_song_panel.connect(_on_opening_song_panel_from_all_songs)
