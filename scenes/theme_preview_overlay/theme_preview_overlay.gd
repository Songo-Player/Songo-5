extends MarginContainer

## A full-screen look at one theme, shown over the UI the way the song info
## panel is: the theme's name, with the arrows over an action button (Apply,
## Download...) in the top right. Below, the preview takes the left half; the
## right half lists its co-authors after "Co-authors:", its download count and
## AI usage (each beside an icon), its tags under "Theme Tags:", then a status
## line. The description
## runs along the bottom in a scrolling carousel label.
##
## It only displays; whoever opens it decides what's shown and what the
## buttons do:
##     var overlay = ThemePreviewOverlay.instantiate()
##     overlay.navigated.connect(func(step): ...; overlay.display({...}))
##     overlay.action_pressed.connect(...)
##     overlay.open()
## Back closes it (emitting closed).

signal navigated(step: int)
signal action_pressed
signal closed

# The overlay is as tall as its contents need, centered on the screen and
# kept this far from its edges. The preview sets most of that height: its
# natural height at half the width, shrunk if the whole overlay wouldn't fit.
const EDGE_GAP := 16
# Height to width, for a preview that hasn't loaded yet (theme previews are 4:3).
const DEFAULT_PREVIEW_RATIO := 0.75
const CHIP_COLOR := Color(0.0646965, 0.0646965, 0.0646965, 1)
const STATUS_COLORS := {
	"info": Color(0.8, 0.8, 0.8, 1),
	"good": Color(0, 0.913725, 0, 1),
	"notice": Color(1, 0.76, 0.2, 1),
	"bad": Color(0.870588, 0, 0, 1),
}

# Frame the overlay opened on; the press that opened it is still "just
# pressed" when _process runs later that frame.
var _opened_frame := -1
var _open := false

## Shows the overlay over everything. Focus starts on the arrows, so left and
## right step through themes straight away; down reaches the action button.
func open() -> void:
	_opened_frame = Engine.get_process_frames()
	_open = true
	UiHelper.open_overlay_panel(self)
	add_theme_constant_override("margin_top", EDGE_GAP)
	add_theme_constant_override("margin_bottom", EDGE_GAP)
	_cap_card_width()
	if not resized.is_connected(_cap_card_width): resized.connect(_cap_card_width)
	if not resized.is_connected(_queue_fit): resized.connect(_queue_fit)
	%PreviewFrame.resized.connect(_queue_fit)
	_queue_fit()
	# After the overlay window is up, so the focus lands in it.
	_focus_default()

var _fit_queued := false

# No wider than the card would be on a 4:3 screen; wider screens add to the sides.
func _cap_card_width() -> void:
	var side := UiHelper.capped_card_side_margin(size, EDGE_GAP)
	add_theme_constant_override("margin_left", side)
	add_theme_constant_override("margin_right", side)

func _queue_fit() -> void:
	if _fit_queued: return
	_fit_queued = true
	_fit_preview.call_deferred()

# Gives the preview its natural height at the width it has (half the overlay),
# or less if that would make the overlay taller than the screen. The rest of
# the overlay sizes itself around it.
func _fit_preview() -> void:
	_fit_queued = false
	var width: float = %PreviewFrame.size.x
	if width <= 0.0: return
	var texture: Texture2D = %PreviewImage.texture
	var ratio := DEFAULT_PREVIEW_RATIO
	if texture != null and texture.get_width() > 0:
		ratio = float(texture.get_height()) / texture.get_width()
	# Everything in the panel but the body row (header, separator, description)...
	var chrome: float = %PanelContainer.get_combined_minimum_size().y - %Body.get_combined_minimum_size().y
	# ...leaves this much for the preview within the screen.
	var room := size.y - 2.0 * EDGE_GAP - chrome
	var height := floorf(minf(width * ratio, room))
	if absf(%PreviewFrame.custom_minimum_size.y - height) >= 1.0:
		%PreviewFrame.custom_minimum_size.y = maxf(height, 0.0)

func _focus_default() -> void:
	if %Arrows.visible: %Arrows.grab_focus()
	else: %ActionButton.grab_focus()

func close() -> void:
	if not _open: return
	_open = false
	closed.emit()
	UiHelper.close_overlay_panel(self)

func is_open() -> bool:
	return _open

## What to show. Every key is optional:
##   name, version, author: the header
##   co_authors: names listed under "Co-authors:" ("None" when empty)
##   preview: a Texture2D
##   description
##   downloads: how many times it's been downloaded; left out, there's no line
##   ai_usage: 0 to 5, or null when the theme doesn't say
##   tags: shown as chips under "Theme Tags"
##   status: a line under the chips; status_kind is "info", "good",
##       "notice" or "bad" for its color
##   action: the action button's text; action_disabled greys it out
##   can_navigate: false hides the arrows (one theme to show)
func display(info: Dictionary) -> void:
	%NameLabel.set_carousel_text(str(info.get("name", "")))
	var byline := []
	if str(info.get("version", "")) != "": byline.append("v%s" % info["version"])
	if str(info.get("author", "")) != "": byline.append("Created by %s" % info["author"])
	%BylineLabel.text = "  ·  ".join(byline)
	%BylineLabel.visible = not byline.is_empty()

	var preview = info.get("preview")
	%PreviewImage.texture = preview if preview is Texture2D else load("res://assets/music.svg")
	_queue_fit()

	var description := str(info.get("description", ""))
	%DescriptionLabel.set_carousel_text(description)
	%DescriptionPanel.visible = description != ""

	set_status(str(info.get("status", "")), str(info.get("status_kind", "info")))
	set_action(str(info.get("action", %ActionButton.text)), info.get("action_disabled", false))
	%Arrows.visible = info.get("can_navigate", true)
	if _open and not %Arrows.visible and %Arrows.has_focus(): %ActionButton.grab_focus()

	var downloads = info.get("downloads")
	%DownloadsRow.visible = typeof(downloads) in [TYPE_INT, TYPE_FLOAT]
	if %DownloadsRow.visible:
		var count := int(downloads)
		%DownloadsLabel.text = "Downloaded %s %s" % [_group_digits(count), "time" if count == 1 else "times"]
	var ai_usage = info.get("ai_usage")
	if typeof(ai_usage) in [TYPE_INT, TYPE_FLOAT] and ai_usage >= 0:
		%AiLabel.text = "AI usage %d out of 5" % int(ai_usage)
	else:
		%AiLabel.text = "AI usage not stated"

	var tags: Array = info.get("tags", [])
	for child in %TagChips.get_children():
		child.queue_free()
	for tag in tags:
		%TagChips.add_child(_make_chip(str(tag)))
	%TagsHeading.visible = not tags.is_empty()
	%TagChips.visible = not tags.is_empty()

	var co_authors := PackedStringArray()
	for name in info.get("co_authors", []):
		if str(name).strip_edges() != "": co_authors.append(str(name).strip_edges())
	%CoAuthorsLabel.set_carousel_text(", ".join(co_authors) if not co_authors.is_empty() else "None")

func _group_digits(value: int) -> String:
	var digits := str(value)
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return digits + out

func set_status(text: String, kind := "info") -> void:
	%StatusLabel.text = text
	%StatusLabel.visible = text != ""
	%StatusLabel.add_theme_color_override("font_color", STATUS_COLORS.get(kind, STATUS_COLORS["info"]))

func set_action(text: String, disabled := false) -> void:
	%ActionButton.text = text
	%ActionButton.disabled = disabled

func set_preview(texture: Texture2D) -> void:
	if texture != null:
		%PreviewImage.texture = texture
		_queue_fit()

# Dark rounded chips for the tags, as in the song info panel.
func _make_chip(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CHIP_COLOR
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	chip.add_child(label)
	return chip

func _process(_delta: float) -> void:
	if not _open or Engine.get_process_frames() == _opened_frame: return
	if Input.is_action_just_pressed("back"):
		close()

func _on_previous_pressed() -> void:
	navigated.emit(-1)

func _on_next_pressed() -> void:
	navigated.emit(1)

func _on_action_pressed() -> void:
	action_pressed.emit()
