@tool
extends PanelContainer

@onready var button: Button = %ItemButton
@onready var icon: TextureRect = %ItemIcon


func _on_item_button_focus_entered() -> void:
	%ItemIcon.modulate = "ff555b"

func _on_item_button_focus_exited() -> void:
	%ItemIcon.modulate = "ffffff"
