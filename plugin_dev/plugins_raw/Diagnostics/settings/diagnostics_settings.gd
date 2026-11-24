extends Resource

## Diagnostics' settings, saved as a .tres in user://. Call save() after
## changing values; it emits `changed` so the overlay can re-apply them.

const SAVE_PATH = "user://diagnostics_settings.tres"

enum Corner { TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT }
const CORNER_NAMES = ["Top Left", "Top Right", "Bottom Left", "Bottom Right"]

## Show the overlay at all.
@export var show_overlay: bool = true
@export var show_cpu: bool = true
@export var show_ram: bool = true
@export var show_fps: bool = true
## Which corner of the screen the overlay sits in (a Corner).
@export var corner: int = Corner.BOTTOM_LEFT

func reset_to_defaults() -> void:
	show_overlay = true
	show_cpu = true
	show_ram = true
	show_fps = true
	corner = Corner.BOTTOM_LEFT

func step_corner(direction: int) -> void:
	corner = wrapi(corner + direction, 0, CORNER_NAMES.size())

func corner_name() -> String:
	return CORNER_NAMES[clampi(corner, 0, CORNER_NAMES.size() - 1)]

func save() -> void:
	var err := ResourceSaver.save(self, SAVE_PATH)
	if err != OK: push_error("Diagnostics: failed to save settings (%s)" % err)
	emit_changed()
