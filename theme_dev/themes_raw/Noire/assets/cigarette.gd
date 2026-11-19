@tool
extends Control
## The song's progress as a cigarette burning down toward the filter. The
## ember brightens with the bass and the smoke curling off it thickens with
## the music, so it doubles as the visualizer. Ash builds up behind the ember
## and drops off every so often. Smoke is drawn above the control's own rect,
## so leave room over it.

const P = preload("palette.gd")

const FILTER_W := 44.0
const BODY_H := 11.0
const MAX_PUFFS := 64
const DB_FLOOR := 60.0
const SMOOTHING := 0.2

@export_range(0.0, 1.0) var progress := 0.3:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
@export var band_color := Color(P.DEFAULT_ACCENT):
	set(value):
		band_color = value
		queue_redraw()
## How tall the smoke is allowed to rise above the cigarette, in pixels.
@export var smoke_height := 70.0
## Mirrors the whole thing: filter on the right, burning left to right.
@export var flipped := false:
	set(value):
		flipped = value
		queue_redraw()

var _spectrum
var _energy := 0.0
var _puffs: Array[Dictionary] = []
var _flakes: Array[Dictionary] = []
var _emit := 0.0
var _ash := 0.0
var _ash_drop_at := 16.0
var _last_tip := -1.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Engine.is_editor_hint():
		_spectrum = SongoPlayer.get_spectrum()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree() or DeviceOS.sleeping: return
	delta = minf(delta, 0.1)
	var lit: bool = SongoPlayer.music_playing
	_energy = lerpf(_energy, _bass() if lit else 0.0, SMOOTHING)

	# Smoke: a lazy curl when paused, a steady stream when the music's loud.
	var rate := (8.0 + _energy * 22.0) if lit else 3.0
	_emit += rate * delta
	while _emit >= 1.0 and _puffs.size() < MAX_PUFFS:
		_emit -= 1.0
		_spawn_puff()
	_emit = minf(_emit, 1.0)
	for puff in _puffs:
		puff.age += delta
		# Rises in a lazy S, slowing and spreading as it goes.
		puff.vel.x += sin(puff.age * 2.6 + puff.seed) * 30.0 * delta
		puff.vel.y *= 1.0 - 0.35 * delta
		puff.pos += puff.vel * delta
		puff.radius += delta * (4.5 + _energy * 3.0)
	_puffs = _puffs.filter(func(puff): return puff.age < puff.life)

	# Ash builds as the ember moves and falls off now and then.
	var tip := _tip_x()
	if _last_tip >= 0.0 and tip < _last_tip:
		_ash += _last_tip - tip
	elif tip > _last_tip + 2.0:
		_ash = 0.0  # a new song: a fresh cigarette
	_last_tip = tip
	if _ash > _ash_drop_at:
		_drop_ash(tip)
	for flake in _flakes:
		flake.vel.y += 180.0 * delta
		flake.pos += flake.vel * delta
		flake.age += delta
	_flakes = _flakes.filter(func(flake): return flake.age < 0.9)
	queue_redraw()

func _bass() -> float:
	if _spectrum == null: return 0.0
	var magnitude: float = _spectrum.get_magnitude_for_frequency_range(30.0, 300.0).length()
	return clampf((linear_to_db(magnitude) + DB_FLOOR) / DB_FLOOR, 0.0, 1.0)

func _mid_y() -> float:
	return size.y - BODY_H / 2.0 - 2.0

func _tip_x() -> float:
	var start := 4.0 + FILTER_W
	var body := maxf(size.x - 4.0 - start, 0.0)
	return start + body * (1.0 - progress)

func _spawn_puff() -> void:
	var rise := _rng.randf_range(18.0, 26.0) * (1.0 + _energy)
	_puffs.append({
		"pos": Vector2(_tip_x() + _rng.randf_range(-1.0, 2.0), _mid_y() - BODY_H / 2.0 + 1.0),
		"vel": Vector2(_rng.randf_range(-4.0, 6.0), -rise),
		"radius": _rng.randf_range(1.0, 2.0),
		"age": 0.0,
		# Gone by the time it reaches smoke_height, however fast it rises.
		"life": smoke_height / rise * _rng.randf_range(0.75, 1.0),
		"seed": _rng.randf() * TAU,
	})

func _drop_ash(tip: float) -> void:
	for i in 3:
		_flakes.append({
			"pos": Vector2(tip + 2.0 + _rng.randf() * minf(_ash, 14.0), _mid_y()),
			"vel": Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(0.0, 20.0)),
			"age": 0.0,
		})
	_ash = 0.0
	_ash_drop_at = _rng.randf_range(12.0, 22.0)

func _draw() -> void:
	# Everything below is laid out filter-left; flipping mirrors it as drawn.
	if flipped:
		draw_set_transform(Vector2(size.x, 0.0), 0.0, Vector2(-1.0, 1.0))
	var y := _mid_y()
	var top := y - BODY_H / 2.0
	var left := 4.0
	var right := size.x - 4.0
	var tip := _tip_x()

	# Where the cigarette used to be: a faint dotted ghost to the end.
	var x := tip + 4.0
	while x < right:
		draw_rect(Rect2(x, y, 2, 1), Color(P.TEXT_DIM, 0.35))
		x += 6.0
	draw_line(Vector2(right, y - 3), Vector2(right, y + 3), Color(P.TEXT_DIM, 0.5), 1.0)

	# Filter, with the maker's band in the accent where it meets the paper.
	draw_rect(Rect2(left, top, FILTER_W, BODY_H), Color("a08a66"))
	for i in range(3, int(FILTER_W), 5):
		draw_rect(Rect2(left + i, top + 2 + (i % 3), 1, 1), Color("7d6a4c"))
	draw_rect(Rect2(left + FILTER_W - 3.0, top, 2.0, BODY_H), band_color)

	# Paper, lit from above.
	var paper_left := left + FILTER_W
	if tip > paper_left:
		draw_rect(Rect2(paper_left, top, tip - paper_left, BODY_H), P.PHOTO_BORDER)
		draw_line(Vector2(paper_left, top + 1.5), Vector2(tip, top + 1.5), Color.WHITE, 1.0)
		draw_line(Vector2(paper_left, top + BODY_H - 0.5), Vector2(tip, top + BODY_H - 0.5), Color("b9b3a6"), 1.0)

	# Ash: a ragged grey stub beyond the ember.
	var ash := minf(_ash, 22.0)
	if ash >= 1.0:
		draw_rect(Rect2(tip, top + 0.5, ash, BODY_H - 1.0), Color("6d6a65"))
		var step := 3.0
		var i := 0
		while step * i < ash:
			var shade := Color("8b8781") if i % 2 == 0 else Color("55524e")
			draw_rect(Rect2(tip + step * i, top + 1.0 + float(i % 3), 2.0, 1.0), shade)
			i += 1

	# Ember, brighter with the bass.
	var lit: bool = Engine.is_editor_hint() or SongoPlayer.music_playing
	var glow := (0.55 + _energy * 0.45) if lit else 0.3
	draw_circle(Vector2(tip, y), 8.0 + _energy * 6.0, Color(P.EMBER, 0.12 * glow))
	draw_circle(Vector2(tip, y), 5.0 + _energy * 2.5, Color(P.EMBER, 0.35 * glow))
	draw_rect(Rect2(tip - 2.0, top, 3.0, BODY_H), Color(P.EMBER, 0.6 + 0.4 * glow))
	draw_rect(Rect2(tip - 1.0, top + 2.0, 1.5, BODY_H - 4.0), Color("ffd890", glow))

	for flake in _flakes:
		draw_rect(Rect2(flake.pos, Vector2(2, 2)), Color("8b8781", 1.0 - flake.age / 0.9))

	for puff in _puffs:
		var t: float = puff.age / puff.life
		var alpha := 0.17 * smoothstep(0.0, 0.1, t) * (1.0 - t) * (1.0 - t)
		draw_circle(puff.pos, puff.radius, Color(0.82, 0.82, 0.85, alpha))
