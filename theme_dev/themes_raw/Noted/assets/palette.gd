@tool
extends RefCounted
## Shared colors, sticky note colors, and the hand-drawn wobble for the Noted
## theme. Every component preloads this.

const PENCIL := Color("696969")        # most writing
const PENCIL_DARK := Color("444444")   # buttons and emphasis
const PENCIL_LIGHT := Color("9a9a9a")  # secondary notes
const PAPER := Color("ffffff")         # polaroid frames, notebook pages
const RULE := Color("8fb8e8")          # notebook ruled lines
const MARGIN_RED := Color("e88f8f")    # notebook margin line
const HIGHLIGHTER := Color("fff36b")   # focus marks
const RED_PEN := Color("e0453a")

## Sticky notes: [fill, edge]. Index tabs cycle through these in order, so
## the first four match the note colors of the original sketch.
const NOTES := [
	[Color("fffab1"), Color("b3ae7b")],  # yellow
	[Color("daf781"), Color("9db35d")],  # green
	[Color("ffcee0"), Color("b3919d")],  # pink
	[Color("b1d3f6"), Color("809ab3")],  # blue
	[Color("ffd7a8"), Color("b39876")],  # orange
	[Color("dcc9f7"), Color("9a8db3")],  # lilac
]

static func note(index: int) -> Color:
	return NOTES[posmod(index, NOTES.size())][0]

static func note_edge(index: int) -> Color:
	return NOTES[posmod(index, NOTES.size())][1]

## Whether hand-drawn lines keep boiling (redrawn a few times a second, like
## animation drawn by hand). Off keeps the wobble but holds it still.
static func wobble() -> bool:
	return bool(_setting("wobble", true))

static func _setting(key: String, fallback):
	# Autoloads don't exist while editing scenes, so the editor gets defaults.
	if Engine.is_editor_hint():
		return fallback
	return ThemeManager.settings.get(key, fallback)
