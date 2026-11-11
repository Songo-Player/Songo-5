extends Control

var directory_container
var song_panel_container
var all_songs_container
var albums_container
var active_container
var songo_data = SongoDataResource.get_instance()
var songo_settings = SongoSettings.get_instance()
var original_size

var debug_press_count = 0
var _last_back_msec := 0

# Not part of songo_app.tscn: loaded on a worker thread while the theme and main
# menu build, then added once the menu is up. See _start_deferred_services.
const OVERLAY_CONTAINER = "res://scenes/overlay_container/overlay_container.tscn"
const LRC_SCRAPE = "res://utilities/lrc_scrape.gd"
const LRC_PROCESS = "res://utilities/lrc_process.gd"
# The themes use a small Latin-only subset of Noto Sans; the CJK one (~4MB) is
# attached as its fallback once the menu is up. See assets/fonts/source.
const LATIN_FONT = "res://assets/fonts/NotoSansCJKjp-Medium-Latin.otf"
const CJK_FONT = "res://assets/fonts/NotoSansCJKjp-Medium.otf"
const SONG_BUTTON = "res://scenes/all_songs_container_v2/song_button_v2.tscn"

# Pages loaded in the background after boot so opening them the first time
# doesn't stall on compiling their scripts. Held here so they stay cached.
var _preloaded_pages := []

func _ready() -> void:
	for path in [OVERLAY_CONTAINER, LRC_SCRAPE, LRC_PROCESS, CJK_FONT]:
		ResourceLoader.load_threaded_request(path)
	var my_theme := load("res://assets/songo_base_theme.tres")
	get_tree().root.theme = my_theme
	Engine.physics_ticks_per_second = 1
	Engine.max_fps = songo_settings.target_fps
	UiHelper.transform_container = %TransformContainer

	await get_tree().process_frame
	ThemeManager.set_current_theme(songo_settings.theme_path)
	

	#if songo_settings.force_screen_fit == true:
		#UiHelper.apply_screen_fit()
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	if OS.get_environment("HIDE_MOUSE"): Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	add_debug_info()
	
	get_tree().paused = false
	Engine.set_time_scale(1.0)
	get_tree().root.set_process(true)
	get_tree().root.set_process_input(true)
	
	UiHelper.app_message = %AppMessage
	UiHelper.content_body = %ContentBody
	UiHelper.content_margin_container = %ContentMargin
	UiHelper.flash_message_box = %FlashMessageBox
	
	UiHelper.apply_scale(songo_settings.ui_scale)
	UiHelper.apply_content_margin(songo_settings.content_margin)

	DeviceOS.fade_out_overlay = %FadeOutOverlay
	DeviceOS.setup_device_hallkey()

	Controller.content_body_node = %ContentBody
	SfxPlayer.set_vol(songo_settings.sfx_volume)
	
	# Before the first main menu so plugin menu items/settings pages are in place.
	#PluginManager.load_plugins()
	Controller.main_menu()
	if songo_settings.auto_import && songo_data.music_directory_paths.size() > 0:
		songo_data.index_mp3s(true)
	DeviceOS.apply_action_bindings()
		
	get_window().go_back_requested.connect(_on_system_back_requested)
	
	boot_up_message()
	_start_deferred_services()

func print_tree_path(node: Node):
	var path := []
	var current := node
	while current:
		path.push_front(current.name)
		current = current.get_parent()
	print("Path:", "/".join(path))
	
	
func _on_system_back_requested() -> void:
	# Fires for both the 3-button back and the gesture-nav edge swipe.
	# Known to emit twice per press on some Android builds (godot#101457) — debounce.
	var now := Time.get_ticks_msec()
	if now - _last_back_msec < 250:
		return
	_last_back_msec = now
	_fire_action(&"back")

func _fire_action(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	press.strength = 1.0
	Input.parse_input_event(press)

	# Release on the next frame, otherwise the press/release collapse into one
	# input flush and `is_action_just_pressed` may never be observed — and if you
	# skip the release entirely the action stays stuck "pressed".
	await get_tree().process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	
func _input(event: InputEvent) -> void:
	
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		if songo_settings.enable_stick_nav == false:
			get_viewport().set_input_as_handled()
			
	# Use this to track down what element is eating your mouse click in dev
	if false && event is InputEventMouseButton and event.pressed:
		var hovered := get_viewport().gui_get_hovered_control()

		if hovered:
			print("Clicked UI element:", hovered.name, " (", hovered.get_class(), ")")
			print_tree_path(hovered)
		else:
			print("Clicked: nothing")


func _process(delta: float) -> void:
	#var rotated = Vector2(480,640)
	#if rotate_disp:
	#	custom_minimum_size = rotated
	#	%TransformContainer.size = Vector2(size.y, size.x)
	#	%TransformContainer.position.x = - size.y
	#	%TransformContainer.get_parent().rotation = deg_to_rad(270)

	if UiHelper.overlay_window && UiHelper.overlay_window.visible:
		return
	
	DeviceOS.translate_inputs(delta)
	if Input.is_action_just_pressed("start") && Input.is_action_just_pressed("select"):
		DeviceOS.wake_screen()
		Controller.quit_songo()

	if Controller.active_container: Controller.active_container.render_ui()

	#if %QuickMenu.showing: return

	if Input.is_action_just_pressed("L2") && Input.is_action_just_pressed("R2"):
		%DebugInfo.visible = not %DebugInfo.visible
		if %DebugInfo.visible:
			add_debug_info()

	UiHelper.route_inputs(Controller.active_container, delta)

func add_debug_info():
	%OSNameLabel.text = "OS name: %s" % DeviceOS.get_os_name()
	%DeviceIdLabel.text = "Device ID: %s" % OS.get_environment("DEVICE_NAME")
	%ScreenSize.text = "Screen Size: %s" % str(DisplayServer.screen_get_size())
	%WindowSize.text = "Window Size: %s" % str(DisplayServer.window_get_size())
	%DeviceOrientation.text = "Device Orientation: %s" % string_screen_orientation()
	%RootSize.text = "Root Size: %s" % str(get_parent().size)
	
func string_screen_orientation():
	var orientation = DisplayServer.screen_get_orientation()
	var strings = [
		"SCREEN_LANDSCAPE",
		"SCREEN_PORTRAIT",
		"SCREEN_REVERSE_LANDSCAPE",
		"SCREEN_REVERSE_PORTRAIT",
		"SCREEN_SENSOR_LANDSCAPE",
		"SCREEN_SENSOR_PORTRAIT",
		"SCREEN_SENSOR"
	]
	return strings[orientation]

func _on_focus_changed(control):
	UiHelper.register_focus_change(control)
	SfxPlayer.play_nav_sfx()
	
# Things that aren't needed for the first screen, started once it's up. The
# services aren't autoloads so compiling them doesn't hold up boot; reach them
# with get_node("/root/<name>").
func _start_deferred_services():
	# Let the main menu draw first
	await get_tree().process_frame
	await get_tree().process_frame

	# Last child of TransformContainer so it draws over everything, as it did
	# when it was part of the scene
	var overlay: Node = (await _finish_threaded_load(OVERLAY_CONTAINER)).instantiate()
	overlay.name = "OverlayContainer"
	%TransformContainer.add_child(overlay)

	# Shared by every theme that uses the Latin font, so this covers them all.
	# Text already drawn with missing glyphs redraws when the font changes.
	var latin_font: FontFile = load(LATIN_FONT)
	var fallbacks := latin_font.fallbacks
	fallbacks.append(await _finish_threaded_load(CJK_FONT))
	latin_font.fallbacks = fallbacks

	var lrc_scrape = _add_service("LrcScrape", await _finish_threaded_load(LRC_SCRAPE))
	var lrc_process = _add_service("LrcProcess", await _finish_threaded_load(LRC_PROCESS))
	# A song may have started before they were listening (e.g. resumed playback)
	var current_song = SongoPlayer.get_current_music_record()
	if current_song != null:
		lrc_scrape._on_started_new_song(current_song)
		lrc_process._on_started_new_song(current_song)

	if OS.get_environment("USE_SONGO_VOL_TCP_SERVER") == "1":
		var listener = _add_service("VolumeTcpListener", load("res://utilities/volume_tcp_listener/volume_tcp_listener.gd"))
		listener.volume_updated.connect(overlay._on_volume_changed)

	_preload_pages()
	ThemeManager.theme_updated.connect(_preload_pages)

# The song list and song view, plus the current theme's parts of them. Opening
# one before its load finishes is fine, load() waits for the threaded load.
func _preload_pages():
	var paths = [Controller.ALL_SONGS_CONTAINER, Controller.SONG_PANEL_CONTAINER, SONG_BUTTON]
	for component in ["collection_header", "collection_button", "main_song_view"]:
		var path = ThemeManager.get_scene_path(component)
		if path is String && ResourceLoader.exists(path): paths.append(path)

	for path in paths:
		ResourceLoader.load_threaded_request(path)
	var loaded := []
	for path in paths:
		loaded.append(await _finish_threaded_load(path))
	# Replaces any previous theme's scenes so they can be freed
	_preloaded_pages = loaded

# Waits on a load_threaded_request without blocking frames. Untyped so callers
# can use the PackedScene / Script it returns directly.
func _finish_threaded_load(path: String):
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var resource = ResourceLoader.load_threaded_get(path)
	# Falls back to a normal load if the threaded one failed
	return resource if resource != null else load(path)

func _add_service(service_name: String, script: Script) -> Node:
	var service: Node = script.new()
	service.name = service_name
	get_tree().root.add_child(service)
	return service

func boot_up_message():
	#Add more of these
	var message_opts = [
		"Try out Rockbox too!",
		"Try out XMPlayer too!",
		"Try the music player pak too!",
		"Try Music Player Daemon too!",
		"Songo#5, now gluten free!",
		"Try out touching grass!",
		"Don't tell Lou's legal team please",
		"Help! i'm trapped in your music directory",
		"Music is better than people",
		"Why is anbernic ghosting me...",
		"Tell Gus I say hi",
		"Just wait till you see Songo#6",
		"Songo#5, now with 3% less malware!",
		"Don't read CSM part 2",
		"Make yourself at hom- DON'T TOUCH THAT",
		"We dont talk about Songo#1-4",
		"Forwarding good vibes to the Xongles",
		"Are you listening to TWRP? You should be.",
		"Six seasons and a movie!",
		"I'm tired boss",
		"Jimmy Pop is an Idol, fight me",
		"Try out Wasabi too!"
	]
	UiHelper.flash_message(message_opts.pick_random(), 5.0)
