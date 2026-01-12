extends Node

const CFW_MUOS = "muOS"
const CFW_KNULLI = "knulli"
const CFW_ROCKNIX = "ROCKNIX"
const CFW_TRIM_UI = "TrimUI"

var fade_out_overlay: Control
var device_strategy: DeviceOsStrategy
var device_strategy_name: get = get_device_strategy_name
var music_dir_tip: get = get_music_dir_tip
var songo_data = SongoDataResource.get_instance()
var songo_settings = SongoSettings.get_instance()
# Screen Brightness Adjustments
var fade_val: float
var fade_tween = null
var sleeping: bool = false
var keep_screen_awake = false

func _init():
	set_device_os_strategy()
	
func _process(delta: float) -> void:
	if fade_tween != null && songo_settings.song_sleep_type == 0:
		set_backlight(int(round(fade_val)))
	
func get_device_strategy_name():
	if device_strategy:
		return device_strategy.get_script().get_global_name()
	else:
		return "None"

func get_music_dir_tip():
	if device_strategy:
		return device_strategy.music_dir_tip
	else:
		return "Looks like you're using unsupported CFW, good luck!"

func get_os_name():
	var initial_name = OS.get_name()
	var post_fix_name = OS.get_environment("CFW_NAME")
	if post_fix_name:
		return "%s - (%s)" % [initial_name, post_fix_name]
	else:
		return initial_name
	
func get_valid_os_strategy():
	if WindowsStrategy.being_used():
		return WindowsStrategy
	elif MuosCanadaGooseStrategy.being_used():
		return MuosCanadaGooseStrategy
	elif KnulliStrategy.being_used():
		return KnulliStrategy
	elif RocknixStrategy.being_used():
		return RocknixStrategy
	elif TrimUIStrategy.being_used():
		return TrimUIStrategy
	return null
	
func set_device_os_strategy():
	if songo_settings.use_generic_strategy == true:
		device_strategy = GenericLinuxStrategy.new()
		return

	var valid_strategy = get_valid_os_strategy().new()
	if valid_strategy: device_strategy = valid_strategy
	else: device_strategy = GenericLinuxStrategy.new()
	
func start_screen_fade():
	match songo_settings.song_sleep_type:
		0:
			if device_strategy.can_fade_screen == false:
				UiHelper.flash_message("Error: 'Bright Fade' attempted on unsupported cfw.")
				return
			fade_tween = create_tween()
			fade_val = device_strategy.target_brightness
			fade_tween.tween_property(self, "fade_val", 0.0, 2.0) # fade over 2 seconds
			fade_tween.finished.connect(Callable(self, "_on_tween_fade_finished"))
		1:
			fade_out_overlay.modulate.a = 0.0
			fade_tween = create_tween()
			fade_tween.tween_property(fade_out_overlay, "modulate:a", 1.0, 2.0)
			fade_tween.finished.connect(Callable(self, "_on_tween_fade_finished"))
		2: 
			return
		_:
			UiHelper.flash_message("Error: Unknown screen fade attempt.")

func _on_tween_fade_finished():
	fade_tween.kill()
	fade_tween = null
	sleeping = true
	if device_strategy.can_fade_screen:
		set_backlight(0)
		fade_out_overlay.modulate.a = 0.0
	else:
		fade_out_overlay.modulate.a = 1.0
	
func set_backlight(level: int):
	if "set_backlight" in device_strategy:
		device_strategy.set_backlight(level)

func wake_screen():
	if sleeping == true || fade_tween != null:
		if fade_tween != null: 
			fade_tween.kill()
			fade_tween = null

		if device_strategy.can_fade_screen:
			set_backlight(device_strategy.target_brightness)
			
		fade_out_overlay.modulate.a = 0.0
		sleeping = false
