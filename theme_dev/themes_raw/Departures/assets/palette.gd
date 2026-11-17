@tool
extends RefCounted
## Shared colors and setting lookups for the Departures theme.
## Every component preloads this, so the board's look is defined in one place.

const BOARD_BG := Color("0b0d10")     # the dark housing of the board
const PANEL := Color("111418")        # raised board panels
const CELL := Color("1a1d22")         # an idle flap
const CELL_FOCUS := Color("22262d")   # a highlighted row
const RULE := Color("23272e")         # thin separator lines
const TEXT := Color("e9e6dc")         # warm white flap lettering
const TEXT_DIM := Color("80848c")     # column headings and secondary info
const ON_TIME := Color("6fcf97")      # "ON TIME" remarks
const PAPER := Color("efe8d8")        # boarding pass card stock
const PAPER_SHADE := Color("e2d9c5")
const INK := Color("1d2026")
const INK_DIM := Color("75705f")

const DEFAULT_BOARD := "f2c230"
const STATION_NAME := "DEPARTURES"

## The accent the board's lettering and highlights are drawn in.
static func board() -> Color:
	return Color(_setting("board_color", DEFAULT_BOARD))

## Light mode is a daylight board: enamel-white flaps with ink letters in a
## clean light station. Where dark mode lights letters in the board color,
## light mode fills the flap with it instead, so the accent is a highlight
## rather than a (muddy) text color.
static func light() -> bool:
	return bool(_setting("light_mode", false))

static func surface() -> Color:       # the page behind everything
	return Color("eeece6") if light() else BOARD_BG

static func panel() -> Color:         # board frames, the ticker, the follow bar
	return Color("fbfaf7") if light() else PANEL

static func rule() -> Color:          # separators and panel borders
	return Color("dcd8cf") if light() else RULE

static func row_focus() -> Color:     # a highlighted row: a wash of the accent
	return accent_fill().lerp(panel(), 0.8) if light() else CELL_FOCUS

static func button() -> Color:        # an idle button
	return Color("fbfaf7") if light() else CELL

static func button_hover() -> Color:
	return Color("f1eee6") if light() else CELL_FOCUS

static func frame() -> Color:         # behind album art and icons
	return Color("ffffff") if light() else CELL

static func text() -> Color:          # text drawn on the page
	return Color("1b1d22") if light() else TEXT

static func text_dim() -> Color:
	return Color("6d6a63") if light() else TEXT_DIM

# Light mode shades for each board color, picked by hand: darkening a color
# by formula turns yellow into olive, so each has its own deep tone instead.
const LIGHT_INKS := {
	"f2c230": "a76a00",  # Station Yellow -> deep amber
	"f4f1e8": "2b2f36",  # Paper White    -> graphite (white can't show on white)
	"ff8a1f": "c2530a",  # Sodium Orange
	"6fcf97": "1d8350",  # Signal Green
	"6ec6ff": "1c6aab",  # Night Blue
	"ff6b8b": "c22b52",  # Neon Pink
}

## The accent for text and thin marks drawn straight on the page.
static func accent_ink() -> Color:
	if not light(): return board()
	var key := board().to_html(false)
	return Color(LIGHT_INKS[key]) if LIGHT_INKS.has(key) else board().darkened(0.45)

## The accent for filled shapes: flaps, bars, stripes, signs.
static func accent_fill() -> Color:
	if light() and board().get_luminance() > 0.85:
		return accent_ink()  # Paper White would vanish on a white page
	return board()

## Text drawn on top of accent_fill().
static func on_accent() -> Color:
	return INK if accent_fill().get_luminance() > 0.45 else Color("fbfaf7")

static func signal_green() -> Color:  # the network indicator
	return Color("1d8350") if light() else ON_TIME

## Flap colors by role: [cell, letters]. "plain" is everyday lettering,
## "accent" a highlighted flap, "on_time" and "alert" the status remarks.
static func flap_colors(role: String) -> Array:
	if not light():
		match role:
			"accent": return [CELL, board()]
			"on_time": return [CELL, ON_TIME]
			"alert": return [CELL, Color(1, 0.45, 0.4)]
			_: return [CELL, TEXT]
	match role:
		"accent": return [accent_fill(), on_accent()]
		"on_time": return [Color("ffffff"), Color("1d8350")]
		"alert": return [Color("ffffff"), Color("c0392b")]
		_: return [Color("ffffff"), Color("1b1d22")]

## The edge around each flap, its hinge line, and the shade of a falling flap.
static func flap_edge() -> Color:
	return Color("d6d1c6") if light() else Color(0, 0, 0, 0)

static func flap_hinge() -> Color:
	return Color(0, 0, 0, 0.16) if light() else Color(0, 0, 0, 0.7)

static func flap_shade() -> Color:
	return Color(0, 0, 0, 0.1) if light() else Color(0, 0, 0, 0.4)

static func flaps_animate() -> bool:
	return bool(_setting("flap_animation", true))

## Follows the app's own 24 hour clock setting.
static func clock_24_hour() -> bool:
	if Engine.is_editor_hint():
		return true
	return SongoSettings.get_instance().clock_24_hour

static func ticket_scale() -> float:
	return float(_setting("ticket_scale", 1.0))

## "HH:MM" (or "H:MM" on a 12 hour clock) for the given hour and minute.
static func clock_text(hour: int, minute: int) -> String:
	if not clock_24_hour():
		hour = hour % 12
		if hour == 0: hour = 12
		return "%2d:%02d" % [hour, minute]
	return "%02d:%02d" % [hour, minute]

static func _setting(key: String, fallback):
	# Autoloads don't exist while editing scenes, so the editor gets defaults.
	if Engine.is_editor_hint():
		return fallback
	return ThemeManager.settings.get(key, fallback)
