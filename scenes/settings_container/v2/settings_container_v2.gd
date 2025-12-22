extends VBoxContainer

class_name SettingsV2Container

func setup():
	%VersionLabel.text = SongoDataResource.VERSION
	
func _ready():
	await get_tree().process_frame
	%DataAndStorageButton.set_focus()
	%ScrollContainer.scroll_vertical = 0

func render_ui():
	pass
	
func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.new_nav_back()

func _on_data_and_storage_button_pressed() -> void:
	Controller.settings_data_and_storage()

func _on_ui_and_customization_button_pressed() -> void:
	Controller.settings_ui_and_customizations()

func _on_misc_feature_settings_button_pressed() -> void:
	Controller.misc_feature_settings()

func _on_playlist_settings_button_pressed() -> void:
	Controller.playlist_settings()

func _on_advanced_settings_button_pressed() -> void:
	Controller.advanced_settings()

func _on_development_credit_button_pressed() -> void:
	Controller.settings_development_credit()
