@tool
extends Control
## Draws text as a row of split-flap cells, like a station departures board.
## Setting new text flips each cell through the drum until it lands on its
## letter. Only redraws while something is flipping, so an idle board is free.

const P = preload("palette.gd")

## The letters printed on each flap's drum, in the order they turn over.
const DRUM := " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789:.-/&'!?#+"
const FLIP_TIME := 0.04        # seconds each flap takes to fall
const MIN_FLIPS := 4            # every changing cell turns at least this many times
const MAX_FLIPS := 10           # ...and at most this many, however far the drum is
const CELL_STAGGER := 0.025     # neighbouring cells start a touch later, left to right

@export var text := "":
	set(value): set_text(value)
	get: return _text
## How many cells to draw. 0 sizes the board to the text.
@export var cells := 0:
	set(value):
		cells = value
		_rebuild()
## Longest text shown when cells is 0. Longer text is cut short.
@export var max_cells := 0:
	set(value):
		max_cells = value
		_rebuild()
@export var cell_size := Vector2(18, 26):
	set(value):
		cell_size = value
		_update_min_size()
@export var gap := 2.0:
	set(value):
		gap = value
		_update_min_size()
@export var font_size := 18:
	set(value):
		font_size = value
		queue_redraw()
@export var font: Font:
	set(value):
		font = value
		queue_redraw()
@export var text_color := Color("e9e6dc"):
	set(value):
		text_color = value
		queue_redraw()
@export var cell_color := P.CELL:
	set(value):
		cell_color = value
		queue_redraw()
## Colors the flaps from the palette for the current mode: "plain",
## "accent", "on_time" or "alert". Empty uses text_color and cell_color as set.
@export var role := "":
	set(value):
		role = value
		queue_redraw()
@export var align_right := false:
	set(value):
		align_right = value
		queue_redraw()
## When cells is 0, show only as many cells as fit the width the layout gives
## this control, instead of asking for room for the whole text.
@export var fit_width := false:
	set(value):
		fit_width = value
		_rebuild()

var _text := ""
var _shown := PackedStringArray()     # the letter each cell currently shows
var _target := PackedStringArray()    # the letter each cell is turning toward
var _flips_left := PackedInt32Array() # flips remaining before a cell lands
var _wait := PackedFloat32Array()     # time until a cell's next flip
var _cell_style: StyleBoxFlat

func _ready() -> void:
	_rebuild()
	set_process(_is_flipping())
	resized.connect(_on_resized)

func _on_resized() -> void:
	if fit_width and _letters_for(_text).size() != _shown.size():
		# Keep any flip that's under way going with the new cell count.
		set_text(_text, _is_flipping())

## Changes the text. Cells flip into place unless animate is false (or the
## flip animation setting is off). delay holds every cell before it starts.
func set_text(value: String, animate := true, delay := 0.0) -> void:
	_text = value
	var letters := _letters_for(value)
	if letters.size() != _shown.size():
		_resize(letters.size())
	var flip := animate and is_inside_tree() and not Engine.is_editor_hint() and P.flaps_animate()
	for i in letters.size():
		_target[i] = letters[i]
		if not flip:
			_shown[i] = letters[i]
			_flips_left[i] = 0
		elif _shown[i] != letters[i]:
			_flips_left[i] = _flip_count(_shown[i], letters[i])
			_wait[i] = delay + i * CELL_STAGGER
	set_process(_is_flipping())
	queue_redraw()

## Flips every cell even if its letter isn't changing, like a board refreshing.
func reflip(delay := 0.0) -> void:
	if not P.flaps_animate() or Engine.is_editor_hint(): return
	for i in _shown.size():
		_flips_left[i] = MIN_FLIPS + (i % 3)
		_wait[i] = delay + i * CELL_STAGGER
	set_process(true)

func _letters_for(value: String) -> PackedStringArray:
	var upper := value.to_upper()
	var count := cells
	if count <= 0:
		count = upper.length()
		if max_cells > 0: count = mini(count, max_cells)
		if fit_width and size.x > 0.0:
			count = mini(count, int((size.x + gap) / (cell_size.x + gap)))
		count = maxi(count, 1)
	var letters := PackedStringArray()
	letters.resize(count)
	for i in count:
		letters[i] = upper[i] if i < upper.length() else " "
	return letters

## How many times a cell turns going from one letter to another. Real flaps
## turn the whole way round the drum, which is too slow for a menu, so the
## flip is capped and starts partway round, landing in drum order.
func _flip_count(from: String, to: String) -> int:
	var a := DRUM.find(from)
	var b := DRUM.find(to)
	if a == -1 or b == -1:
		return MIN_FLIPS + randi() % 3
	var distance := posmod(b - a, DRUM.length())
	return clampi(distance, MIN_FLIPS, MAX_FLIPS)

func _process(delta: float) -> void:
	var changed := false
	for i in _shown.size():
		if _flips_left[i] <= 0: continue
		_wait[i] -= delta
		if _wait[i] > 0.0: continue
		_wait[i] += FLIP_TIME
		_flips_left[i] -= 1
		_shown[i] = _letter_before_landing(_target[i], _flips_left[i])
		changed = true
	if changed: queue_redraw()
	if not _is_flipping(): set_process(false)

func _letter_before_landing(target: String, flips_left: int) -> String:
	if flips_left <= 0: return target
	var at := DRUM.find(target)
	if at == -1: return DRUM[randi() % DRUM.length()]
	return DRUM[posmod(at - flips_left, DRUM.length())]

func _is_flipping() -> bool:
	for left in _flips_left:
		if left > 0: return true
	return false

func _rebuild() -> void:
	var letters := _letters_for(_text)
	_resize(letters.size())
	for i in letters.size():
		_shown[i] = letters[i]
		_target[i] = letters[i]
	queue_redraw()

func _resize(count: int) -> void:
	var old := _shown.size()
	_shown.resize(count)
	_target.resize(count)
	_flips_left.resize(count)
	_wait.resize(count)
	for i in range(old, count):
		_shown[i] = " "
		_target[i] = " "
		_flips_left[i] = 0
		_wait[i] = 0.0
	_update_min_size()

func _update_min_size() -> void:
	var count := 1 if fit_width else _shown.size()
	custom_minimum_size = Vector2(maxf(count * (cell_size.x + gap) - gap, 0.0), cell_size.y)
	queue_redraw()

## Redraws with the palette's current colors, e.g. after a settings change.
func refresh() -> void:
	queue_redraw()

func _style(fill: Color) -> StyleBoxFlat:
	if _cell_style == null:
		_cell_style = StyleBoxFlat.new()
		_cell_style.set_corner_radius_all(2)
		_cell_style.anti_aliasing = false
	_cell_style.bg_color = fill
	var edge := P.flap_edge()
	_cell_style.border_color = edge
	_cell_style.set_border_width_all(1 if edge.a > 0.0 else 0)
	return _cell_style

func _draw() -> void:
	var f := font if font else get_theme_default_font()
	var count := _shown.size()
	var width := count * (cell_size.x + gap) - gap
	var x := size.x - width if align_right else 0.0
	var y := floorf((size.y - cell_size.y) / 2.0)
	# A FontVariation reports the tallest metrics of its fallbacks, which would
	# throw the letters off centre, and draws shifted by its baseline_offset.
	# Centre on the base font's own metrics and undo that shift instead.
	var metrics := f
	var shift := 0.0
	if f is FontVariation and (f as FontVariation).base_font:
		metrics = (f as FontVariation).base_font
		shift = (f as FontVariation).baseline_offset * font_size
	var ascent := metrics.get_ascent(font_size)
	var descent := metrics.get_descent(font_size)
	var hinge := floorf(cell_size.y / 2.0)
	var fill := cell_color
	var ink := text_color
	if role != "":
		var colors := P.flap_colors(role)
		fill = colors[0]
		ink = colors[1]
	var light := P.light()
	# In daylight only the flaps carrying a letter are lit in the accent, so a
	# highlighted word reads as a highlight rather than a solid bar.
	var blank_fill := fill
	if light and role == "accent":
		blank_fill = P.flap_colors("plain")[0]
	var hinge_color := P.flap_hinge()
	var shade := P.flap_shade()

	for i in count:
		var cell := Rect2(Vector2(x + i * (cell_size.x + gap), y), cell_size)
		var lit := _shown[i] != " " or _flips_left[i] > 0
		draw_style_box(_style(fill if lit else blank_fill), cell)
		# The top flap catches a little more light than the bottom one.
		if not light:
			draw_rect(Rect2(cell.position, Vector2(cell.size.x, hinge)), Color(1, 1, 1, 0.035))

		var letter := _shown[i]
		if letter != " ":
			var w := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var baseline := cell.position.y + roundf((cell.size.y + ascent - descent) / 2.0 - shift)
			draw_string(f, Vector2(cell.position.x + roundf((cell.size.x - w) / 2.0), baseline),
				letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)

		if _flips_left[i] > 0:
			# A falling flap shades the lower half while it's mid-turn.
			draw_rect(Rect2(cell.position + Vector2(0, hinge), Vector2(cell.size.x, cell.size.y - hinge)), shade)

		# The hinge gap between the two halves of each flap.
		draw_rect(Rect2(cell.position + Vector2(0, hinge), Vector2(cell.size.x, 1)), hinge_color)
