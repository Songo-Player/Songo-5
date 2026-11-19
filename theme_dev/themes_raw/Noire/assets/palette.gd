@tool
extends RefCounted
## Shared colors and setting lookups for Noire.
## The whole theme is black and white film stock with a single spot color,
## the accent, used sparingly: stamps, the focus edge, the neon outside.

const NIGHT := Color("09090a")        # the room with the lights off
const PANEL := Color("111113")        # raised panels, the title card
const CARD := Color("19191c")         # buttons, idle frames
const LIT := Color("232328")          # a row under the spotlight
const RULE := Color("2c2c31")         # thin separators
const TEXT := Color("e6e1d6")         # silver screen white
const TEXT_BRIGHT := Color("fffaf0")  # text under the spotlight
const TEXT_DIM := Color("85817a")     # captions, secondary info
const PAPER := Color("e4ddcc")        # the dossier sheet
const PAPER_EDGE := Color("c9c0aa")
const INK := Color("1c1a17")          # typewriter ribbon
const INK_DIM := Color("766e5f")
const PHOTO_BORDER := Color("ece8de") # a glossy print's white border
const EMBER := Color("ff6a2a")

const DEFAULT_ACCENT := "c8102e"

## The spot color.
static func accent() -> Color:
	return Color(_setting("accent", DEFAULT_ACCENT))

## The accent where it's used for text or thin lines on the dark page. Deep
## reds and blues are lifted a little so they stay legible on near black.
static func accent_ink() -> Color:
	var c := accent()
	return c.lightened(0.3) if c.get_luminance() < 0.35 else c

## The accent as ink on the dossier's paper. Pale accents would vanish, so
## they're pressed much darker.
static func accent_on_paper() -> Color:
	var c := accent()
	return c.darkened(0.55) if c.get_luminance() > 0.5 else c

## Text drawn on top of a filled accent shape.
static func on_accent() -> Color:
	return INK if accent().get_luminance() > 0.5 else TEXT_BRIGHT

## The light that falls through the blinds: mostly a warm white, tinted a
## little by the neon sign outside.
static func blind_light() -> Color:
	return Color("fff4e0").lerp(accent(), 0.3)

static func rain() -> bool:
	return bool(_setting("rain", true))

static func film_grain() -> bool:
	return bool(_setting("film_grain", true))

static func monochrome_art() -> bool:
	return bool(_setting("monochrome_art", true))

## Follows the app's own 24 hour clock setting.
static func clock_24_hour() -> bool:
	if Engine.is_editor_hint():
		return false
	return SongoSettings.get_instance().clock_24_hour

## "23:05", or "11:05 PM" on a 12 hour clock.
static func clock_text(hour: int, minute: int) -> String:
	if clock_24_hour():
		return "%02d:%02d" % [hour, minute]
	var suffix := "PM" if hour >= 12 else "AM"
	hour = hour % 12
	if hour == 0: hour = 12
	return "%d:%02d %s" % [hour, minute, suffix]

## Song positions and lengths as m:ss.
static func duration_text(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]

## Roman numerals for menu reels and track numbers. Plain digits past 39.
static func roman(n: int) -> String:
	if n <= 0 or n > 39: return str(n)
	var out := ""
	for pair in [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]:
		while n >= pair[0]:
			out += pair[1]
			n -= pair[0]
	return out

## A stable case number for anything with a path or name, e.g. "0427-B".
static func case_number(key: String) -> String:
	var h := absi(key.hash())
	return "%04d-%s" % [h % 10000, char(65 + (h / 10000) % 26)]

static func _setting(key: String, fallback):
	# Autoloads don't exist while editing scenes, so the editor gets defaults.
	if Engine.is_editor_hint():
		return fallback
	return ThemeManager.settings.get(key, fallback)
