extends HBoxContainer
signal removed_dir
@onready var songo_data = SongoDataResource.get_instance()
var directory_path = ""

func setup(path):
	$CarouselLabel.set_carousel_text(path)
	directory_path = path

func _on_button_pressed() -> void:
	songo_data.remove_music_directory_path(directory_path)
	removed_dir.emit()
