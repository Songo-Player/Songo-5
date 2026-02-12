extends MarginContainer

var songo_settings = SongoSettings.get_instance()
var temp_strategy_name
var change_attempted: bool = false

func setup():
	pass
	
func _ready():
	await get_tree().process_frame
	%PageLabel.grab_focus()
	$ScrollContainer.scroll_vertical = 0
	temp_strategy_name = DeviceOS.device_strategy.strategy_name
	update_device_strategy_ui()
	update_stream_buffer_length_ui()

func render_ui():
	pass
	
func update_device_strategy_ui():
	%DeviceStrategyLabel.text = temp_strategy_name
	%StrategySaveQuitSection.visible = temp_strategy_name != DeviceOS.device_strategy.strategy_name
	
func update_stream_buffer_length_ui():
	%BufferLengthLabel.text = "%dms" % songo_settings.stream_buffer_length
	
func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		if change_attempted:
			UiHelper.flash_message("Strategy change cancelled, keeping old strategy.")
		Controller.new_nav_back()
	
func _on_strategy_swap_button_pressed() -> void:
	var new_strat = DeviceOS.get_valid_os_strategy()
	if new_strat == null:
		UiHelper.flash_message("GenericLinuxStrategy is the only option for your CFW.")
		return
	change_attempted = true

	if temp_strategy_name == "GenericLinuxStrategy": temp_strategy_name = new_strat.get_global_name()
	else: temp_strategy_name = "GenericLinuxStrategy"
		
	update_device_strategy_ui()

func _on_save_and_quit_button_pressed() -> void:
	songo_settings.use_generic_strategy = temp_strategy_name == "GenericLinuxStrategy"
	songo_settings.save()
	Controller.quit_songo()


func _on_buffer_length_down_pressed() -> void:
	songo_settings.stream_buffer_length -= 5
	if songo_settings.stream_buffer_length <= 0:
		songo_settings.stream_buffer_length = 500
	songo_settings.save()
	update_stream_buffer_length_ui()
	if UiHelper.mini_song_panel.visible:
		UiHelper.dismiss_mini_song_panel()
		UiHelper.flash_message("Song dismissed due to stream buffer length change.")

func _on_buffer_length_up_button_up() -> void:
	songo_settings.stream_buffer_length += 5
	if songo_settings.stream_buffer_length >= 505:
		songo_settings.stream_buffer_length = 5
	songo_settings.save()
	update_stream_buffer_length_ui()
	if UiHelper.mini_song_panel.visible:
		UiHelper.dismiss_mini_song_panel()
		UiHelper.flash_message("Song dismissed due to stream buffer length change.")



func _on_buffer_length_down_focus_entered() -> void:
	$ScrollContainer.scroll_vertical = 9999

func _on_buffer_length_up_focus_entered() -> void:
	$ScrollContainer.scroll_vertical = 9999
