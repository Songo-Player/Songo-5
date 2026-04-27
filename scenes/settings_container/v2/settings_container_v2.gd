extends VBoxContainer

class_name SettingsV2Container

var songo_data = SongoDataResource.get_instance()

func setup():
	%VersionLabel.text = SongoDataResource.VERSION
	
func _ready():
	await get_tree().process_frame
	%DataAndStorageButton.set_focus()
	%ScrollContainer.scroll_vertical = 0
	if songo_data.music_directory_paths.size() == 0:
		UiHelper.app_message.show_message("Start by adding your music directory in 'Data and Storage'")

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


func _on_tree_entered() -> void:
	if songo_data.music_directory_paths.size() == 0:
		%StartHereLabel.show()
	else:
		%StartHereLabel.hide()

func _on_contact_me_button_pressed() -> void:
	Controller.contact_me()

func _on_support_me_button_pressed() -> void:
	Controller.support_me()


func _on_data_and_storage_button_focused() -> void:
	%ScrollContainer.scroll_vertical = 0

func _on_support_me_button_focused() -> void:
	%ScrollContainer.scroll_vertical = 9999

func _on_controller_settings_button_pressed() -> void:
	Controller.controller_settings()

func _on_sound_settings_button_pressed() -> void:
	Controller.sound_settings()
