extends MarginContainer

var songo_settings = SongoSettings.get_instance()
var temp_strategy_name
var change_attempted: bool = false

func setup():
	pass
	
func _ready():
	await get_tree().process_frame
	%PageLabel.grab_focus()
	temp_strategy_name = DeviceOS.device_strategy.strategy_name
	update_device_strategy_ui()

func render_ui():
	pass
	
func update_device_strategy_ui():
	%DeviceStrategyLabel.text = temp_strategy_name
	%StrategySaveQuitSection.visible = temp_strategy_name != DeviceOS.device_strategy.strategy_name
	
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
