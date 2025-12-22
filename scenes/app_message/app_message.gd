extends PanelContainer

func show_message(text: String):
	%SettingsMessageLabel.text = text
	show()
	UiHelper.dark_out.show()
	%DismissMessage.grab_focus()
	
func dismiss():
	hide()
	UiHelper.dark_out.hide()
	UiHelper.focus_back()
	
func _on_dismiss_message_pressed() -> void:
	dismiss()
