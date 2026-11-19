extends MarginContainer
## Bottom of the page: where you are, written on a strip of masking tape,
## and the app version jotted small in pencil.

const Squiggle = preload("../assets/squiggle.gd")

# Tape past each end of the writing.
const TAPE_PADDING := 14.0

func _ready() -> void:
	%VersionLabel.text = "v" + str(SongoDataResource.VERSION).trim_prefix("v").trim_prefix("V")
	%RouteLabel.material = Squiggle.material(0.15)
	%VersionLabel.material = Squiggle.material(0.15)
	_update_route()
	Controller.page_changed.connect(_update_route)

func _update_route() -> void:
	%RouteLabel.text = " > ".join(Controller.nav_label).to_lower()
	_fit_tape.call_deferred()

# The tape is torn to fit what's written on it.
func _fit_tape() -> void:
	var label: Label = %RouteLabel
	var font := label.get_theme_font("font")
	var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
	%Tape.length = minf(width, label.size.x) + TAPE_PADDING * 2.0
