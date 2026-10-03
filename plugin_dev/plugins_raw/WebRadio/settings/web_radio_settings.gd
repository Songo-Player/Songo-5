extends Resource

## Web Radio's settings, saved as a .tres in user://. Call save() after
## changing values; it emits `changed` so the plugin can re-apply them.

const SAVE_PATH = "user://web_radio_settings.tres"
const BUFFER_OPTIONS: Array[float] = [0.5, 1.0, 2.0, 4.0, 8.0]
const TIMEOUT_OPTIONS: Array[float] = [5.0, 10.0, 20.0, 30.0]

## When a stream can't be reached, move on to the station's next stream.
@export var auto_failover: bool = true
## Show the current track for stations that broadcast it.
@export var show_stream_titles: bool = true
## Seconds of audio buffered for network streams.
@export var stream_buffer_length: float = 1.0
## Seconds to wait on an unresponsive stream before giving up.
@export var network_timeout: float = 10.0

func reset_to_defaults() -> void:
	auto_failover = true
	show_stream_titles = true
	stream_buffer_length = 1.0
	network_timeout = 10.0

func save() -> void:
	var err := ResourceSaver.save(self, SAVE_PATH)
	if err != OK: push_error("WebRadio: failed to save settings (%s)" % err)
	emit_changed()

## Steps a value through its options list, wrapping at either end. Values not
## in the list (e.g. from an older save) restart from the first option.
static func step_option(options: Array, current: float, direction: int) -> float:
	var index := options.find(current)
	if index == -1: return options[0]
	return options[wrapi(index + direction, 0, options.size())]
