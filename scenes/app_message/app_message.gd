extends PanelContainer

func show_message(text: String):
	get_parent().move_child(self, -1)
	%SettingsMessageLabel.text = text
	show()
	# The overlay (and its darkout) is added just after boot
	if UiHelper.darkout: UiHelper.darkout.show()
	%DismissMessage.grab_focus()
	get_tree().paused = true
	
func dismiss():
	hide()
	if UiHelper.darkout: UiHelper.darkout.hide()
	UiHelper.focus_back()
	get_tree().paused = false
	
func _on_dismiss_message_pressed() -> void:
	dismiss()
