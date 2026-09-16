extends Control

@onready var dark_out = %DarkOut

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

func _ready() -> void:
	var my_theme := load("res://songo_base_theme.tres")
	get_tree().root.theme = my_theme
	Engine.physics_ticks_per_second = 1
	Engine.max_fps = 60
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
	
	UiHelper.dark_out = %DarkOut
	UiHelper.app_message = %AppMessage
	UiHelper.main_color_panel = %MainColorPanel
	UiHelper.content_body = %ContentBody
	UiHelper.content_margin_container = %ContentMargin
	UiHelper.keyboard = %Keyboard
	UiHelper.flash_message_box = %FlashMessageBox
	UiHelper.info_panel = %InfoPanel
	UiHelper.vol_container = %VolumeContainer
	UiHelper.crt_overlay = %CrtOverlay
	UiHelper.the_grid_overlay = %TheGridOverlay
	
	UiHelper.apply_scale(songo_settings.ui_scale)
	UiHelper.apply_content_margin(songo_settings.content_margin)

	DeviceOS.fade_out_overlay = %FadeOutOverlay
	DeviceOS.setup_device_hallkey()

	Controller.content_body_node = %ContentBody
	SfxPlayer.set_vol(songo_settings.sfx_volume)
	
	Controller.main_menu()
	if songo_settings.auto_import && songo_data.music_directory_paths.size() > 0:
		songo_data.index_mp3s()
	if songo_settings.ab_layout_swapped:
		DeviceOS.swap_input_actions("back", "ui_accept")
	if songo_settings.xy_layout_swapped:
		DeviceOS.swap_input_actions("x", "Y")
		
	get_window().go_back_requested.connect(_on_system_back_requested)
	boot_up_message()

	
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

	if %InfoPanel.visible:
		return
		
	DeviceOS.device_strategy.translate_inputs(delta)
	if Input.is_action_just_pressed("start") && Input.is_action_just_pressed("select"):
		DeviceOS.wake_screen()
		Controller.quit_songo()

	if Controller.active_container: Controller.active_container.render_ui()

	if %QuickMenu.showing: return

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
	if DeviceOS.device_strategy.can_fade_screen:
		%BrightnessLabel.text = "Initial Brightness: %d" % DeviceOS.device_strategy.target_brightness

	
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
	
func boot_up_message():
	#Add more of these
	var message_opts = [
		"Try out Rockbox too!",
		"Try out XMPlayer too!",
		"Using nextUI? Try the music player pak!",
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
		"We dont talk about Songo#1-4"
	]
	UiHelper.flash_message(message_opts.pick_random(), 5.0)
