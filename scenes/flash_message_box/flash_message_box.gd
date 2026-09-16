extends VBoxContainer

const FLASH_MESSAGE = "res://scenes/flash_message_box/flash_message.tscn"
func add_message(message: String, persist_time: float, type: FlashMessage.TYPE):
	var new_message = load(FLASH_MESSAGE).instantiate()
	new_message.setup(message, persist_time, type)
	add_child(new_message)
