extends MarginContainer

var songo_settings = SongoSettings.get_instance()
var _active_input_field = null

func setup():
	if not ClassDB.class_exists("SubsonicNode"):
		%NoExtensionLabel.show()
		%SettingsContent.hide()
		return
	%NoExtensionLabel.hide()
	%SettingsContent.show()
	update_ui()

func _ready():
	await get_tree().process_frame
	if %SettingsContent.visible:
		%PageLabel.grab_focus()
	%ScrollContainer.scroll_vertical = 0

func render_ui():
	pass

func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		if UiHelper.keyboard.visible:
			UiHelper.keyboard.dismiss()
			_cleanup_keyboard()
			return
		Controller.nav_back()
	if Input.is_action_just_pressed("ui_accept"):
		var focused = get_viewport().gui_get_focus_owner()
		if focused == %ServerUrlInput or focused == %UsernameInput or focused == %PasswordInput:
			_show_keyboard_for(focused)

func update_ui():
	%ServerUrlInput.text = songo_settings.subsonic_url
	%UsernameInput.text = songo_settings.subsonic_username
	%PasswordInput.text = songo_settings.subsonic_password
	_update_connection_status()

func _update_connection_status():
	if SubsonicManager and SubsonicManager.connected:
		%ConnectionStatus.text = "Connected"
		%ConnectionStatus.add_theme_color_override("font_color", Color(0, 1, 0))
		%ConnectButton.text = "Disconnect"
	else:
		%ConnectionStatus.text = "Disconnected"
		%ConnectionStatus.add_theme_color_override("font_color", Color(1, 0, 0))
		%ConnectButton.text = "Connect"

func _on_connect_button_pressed():
	if SubsonicManager.connected:
		SubsonicManager.disconnect_from_server()
		songo_settings.subsonic_connected = false
		songo_settings.save()
		_update_connection_status()
		UiHelper.flash_message("Disconnected from Subsonic server")
		return

	var url = %ServerUrlInput.text.strip_edges()
	var username = %UsernameInput.text.strip_edges()
	var password = %PasswordInput.text

	if url.is_empty() or username.is_empty() or password.is_empty():
		UiHelper.flash_message("Please fill in all fields")
		return

	%ConnectButton.disabled = true
	%ConnectButton.text = "Connecting..."

	songo_settings.subsonic_url = url
	songo_settings.subsonic_username = username
	songo_settings.subsonic_password = password
	songo_settings.save()

	if SubsonicManager.connect_to_server(url, username, password):
		songo_settings.subsonic_connected = true
		songo_settings.save()
		_update_connection_status()
		UiHelper.flash_message("Connected to Subsonic server")
	else:
		_update_connection_status()

	%ConnectButton.disabled = false

func _on_server_url_input_text_changed(new_text: String):
	songo_settings.subsonic_url = new_text
	songo_settings.save()

func _on_username_input_text_changed(new_text: String):
	songo_settings.subsonic_username = new_text
	songo_settings.save()

func _on_password_input_text_changed(new_text: String):
	songo_settings.subsonic_password = new_text
	songo_settings.save()

func _on_tree_entered():
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

func _on_tree_exiting():
	get_viewport().gui_focus_changed.disconnect(_on_focus_changed)

func _on_focus_changed(item: Control):
	if item == %ConnectButton:
		%ScrollContainer.scroll_vertical = 999

func _show_keyboard_for(field: LineEdit):
	if UiHelper.keyboard.visible:
		return
	_active_input_field = field
	var title = ""
	if field == %ServerUrlInput:
		title = "Enter Server URL"
	elif field == %UsernameInput:
		title = "Enter Username"
	elif field == %PasswordInput:
		title = "Enter Password"
	var keyboard = UiHelper.keyboard
	if keyboard.keyboard_result.is_connected(_on_keyboard_result):
		keyboard.keyboard_result.disconnect(_on_keyboard_result)
	keyboard.keyboard_result.connect(_on_keyboard_result)
	keyboard.setup(title, %ConnectButton, field.text)

func _on_keyboard_result(result: String):
	var keyboard = UiHelper.keyboard
	if keyboard.keyboard_result.is_connected(_on_keyboard_result):
		keyboard.keyboard_result.disconnect(_on_keyboard_result)
	if _active_input_field == null:
		return
	_active_input_field.text = result
	var trimmed = result.strip_edges()
	if _active_input_field == %ServerUrlInput:
		songo_settings.subsonic_url = trimmed
	elif _active_input_field == %UsernameInput:
		songo_settings.subsonic_username = trimmed
	elif _active_input_field == %PasswordInput:
		songo_settings.subsonic_password = trimmed
	songo_settings.save()
	_active_input_field = null

func _cleanup_keyboard():
	var keyboard = UiHelper.keyboard
	if keyboard.keyboard_result.is_connected(_on_keyboard_result):
		keyboard.keyboard_result.disconnect(_on_keyboard_result)
	_active_input_field = null
