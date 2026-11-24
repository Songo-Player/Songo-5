extends MarginContainer

## The on-screen readout. Covers the whole screen without taking input, and
## shows a small panel in the chosen corner. Stats are sampled once a second,
## and not at all while hidden, so the overlay adds next to no load itself.

const SystemStats = preload("system_stats.gd")
const DiagnosticsSettings = preload("settings/diagnostics_settings.gd")
const SAMPLE_INTERVAL_SEC = 1.0
const EDGE_MARGIN = 6
const FONT_SIZE = 14

var settings

var _stats := SystemStats.new()
var _supported := _stats.is_supported()
var _timer := Timer.new()
var _panel := PanelContainer.new()
var _label := Label.new()

func _ready() -> void:
	# Offsets too: the screen is already sized when this is added, and anchors
	# alone would keep this at zero size.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Over the theme's pages and the overlay container (z 1). Panels opened in
	# the overlay window (info panel, quick menu...) still draw over this.
	z_index = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	for side in ["left", "top", "right", "bottom"]:
		add_theme_constant_override("margin_" + side, EDGE_MARGIN)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	# The UI theme applies down here too, so the look is pinned explicitly to
	# stay readable whatever theme is in use. Godot's built-in font keeps it
	# compact too; some theme fonts have very tall line heights.
	_label.add_theme_font_override("font", ThemeDB.fallback_font)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_constant_override("line_spacing", 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)

	_timer.wait_time = SAMPLE_INTERVAL_SEC
	_timer.timeout.connect(_refresh)
	add_child(_timer)

	settings.changed.connect(_apply_settings)
	_apply_settings()

func _apply_settings() -> void:
	var any_stat: bool = settings.show_cpu or settings.show_ram or settings.show_fps
	var showing: bool = settings.show_overlay and any_stat
	visible = showing
	if showing:
		if _timer.is_stopped():
			# Just shown. CPU is measured between samples; start over rather
			# than report an average stretching back across the hidden time.
			_stats = SystemStats.new()
			_timer.start()
		_place_panel()
		_refresh()
	else:
		_timer.stop()

func _place_panel() -> void:
	var right: bool = settings.corner in [DiagnosticsSettings.Corner.TOP_RIGHT, DiagnosticsSettings.Corner.BOTTOM_RIGHT]
	var bottom: bool = settings.corner in [DiagnosticsSettings.Corner.BOTTOM_LEFT, DiagnosticsSettings.Corner.BOTTOM_RIGHT]
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_END if right else Control.SIZE_SHRINK_BEGIN
	_panel.size_flags_vertical = Control.SIZE_SHRINK_END if bottom else Control.SIZE_SHRINK_BEGIN
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT

func _refresh() -> void:
	if _supported: _stats.sample()
	var lines: PackedStringArray = []
	if settings.show_fps:
		lines.append("FPS %d" % Engine.get_frames_per_second())
	if settings.show_cpu:
		lines.append("CPU " + (_format_percent(_stats.cpu_percent) if _supported else "n/a"))
	if settings.show_ram:
		lines.append("RAM " + _ram_text())
	_label.text = "\n".join(lines)

func _ram_text() -> String:
	if not _supported:
		# No /proc (Windows): only Godot's own allocations are known, which
		# leaves out textures, audio decoding and native libraries.
		return "%s (Godot only)" % _format_bytes(OS.get_static_memory_usage())
	if _stats.ram_bytes < 0: return "--"
	var percent := _stats.ram_percent()
	if percent < 0.0: return _format_bytes(_stats.ram_bytes)
	return "%s (%s)" % [_format_bytes(_stats.ram_bytes), _format_percent(percent)]

func _format_percent(percent: float) -> String:
	if percent < 0.0: return "--"
	return "%.1f%%" % percent

func _format_bytes(bytes: int) -> String:
	return "%d MB" % roundi(bytes / 1048576.0)
