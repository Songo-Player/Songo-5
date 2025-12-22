extends VBoxContainer

const FLASH_MESSAGE = "res://scenes/flash_message_box/flash_message.tscn"
func add_message(message: String):
	var new_message = load(FLASH_MESSAGE).instantiate()
	new_message.setup(message)
	add_child(new_message)
