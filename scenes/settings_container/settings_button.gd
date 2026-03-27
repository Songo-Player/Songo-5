extends Button

func _on_pressed() -> void:
	SfxPlayer.play_accept_sfx()


func _on_mouse_entered() -> void:
	grab_focus()
