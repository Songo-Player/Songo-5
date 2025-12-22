extends HBoxContainer
signal removed_dir
@onready var songo_data = SongoDataResource.get_instance()
var directory_path = ""

func setup(path):
	$Label.text = path
	directory_path = path

func _on_button_pressed() -> void:
	songo_data.music_directory_paths.erase(directory_path)
	songo_data.save()
	removed_dir.emit()
