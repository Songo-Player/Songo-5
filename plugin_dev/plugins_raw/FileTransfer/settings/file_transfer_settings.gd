extends Resource

## File Transfer's settings, saved as a .tres in user://. Whether the server is
## running isn't one of them: it's always off until started from the page.

const SAVE_PATH = "user://file_transfer_settings.tres"
const PORT_OPTIONS: Array[int] = [5005, 5500, 8000, 8080, 8888, 9000]

## The music directory files go in. Empty, or one that's no longer a music
## directory, means the first one.
@export var music_directory: String = ""
@export var port: int = 5005
## Ask the browser for the PIN shown on the settings page.
@export var require_pin: bool = true

func reset_to_defaults() -> void:
	music_directory = ""
	port = PORT_OPTIONS[0]
	require_pin = true

func step_port(direction: int) -> void:
	# An unlisted port (find gives -1) restarts from the first option
	var index := PORT_OPTIONS.find(port)
	port = PORT_OPTIONS[0] if index == -1 else PORT_OPTIONS[wrapi(index + direction, 0, PORT_OPTIONS.size())]

func save() -> void:
	var err := ResourceSaver.save(self, SAVE_PATH)
	if err != OK: push_error("FileTransfer: failed to save settings (%s)" % err)
	emit_changed()
