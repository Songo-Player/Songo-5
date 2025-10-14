extends Node

const CFW_MUOS = "muOS"
const CFW_KNULLI = "knulli"

var device_strategy: DeviceOsStrategy
var device_strategy_name: get = get_device_strategy_name
var music_dir_tip: get = get_music_dir_tip

# Screen Brightness Adjustments
var fade_val: float
var fade_tween = null

func _init():
	set_device_os_strategy()
	
func _process(delta: float) -> void:
	if fade_tween != null:
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
	
func set_device_os_strategy():
	if WindowsStrategy.being_used():
		device_strategy = WindowsStrategy.new()
	elif MuosCanadaGooseStrategy.being_used():
		device_strategy = MuosCanadaGooseStrategy.new()
	elif KnulliStrategy.being_used():
		device_strategy = KnulliStrategy.new()
	else:
		device_strategy = GenericLinuxStrategy.new()
		
func start_screen_fade():
	if device_strategy.can_fade_screen == false: return
	fade_tween = create_tween()
	fade_val = device_strategy.target_brightness
	fade_tween.tween_property(self, "fade_val", 0.0, 2.0) # fade over 2 seconds
	fade_tween.finished.connect(Callable(self, "_on_tween_fade_finished"))

func _on_tween_fade_finished():
	fade_tween.kill()
	fade_tween = null
	set_backlight(0)
	
func set_backlight(level: int):
	OS.execute("sh", ["-c", "echo setbl > /sys/kernel/debug/dispdbg/command"])
	OS.execute("sh", ["-c", "echo lcd0 > /sys/kernel/debug/dispdbg/name"])
	OS.execute("sh", ["-c", "echo " + str(level) + " > /sys/kernel/debug/dispdbg/param"])
	OS.execute("sh", ["-c", "echo 1 > /sys/kernel/debug/dispdbg/start"])
	
func wake_screen():
	if device_strategy.can_fade_screen:
		if fade_tween != null: 
			fade_tween.kill()
			fade_tween = null
		set_backlight(device_strategy.target_brightness)
