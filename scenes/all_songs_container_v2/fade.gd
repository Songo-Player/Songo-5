extends TextureRect
class_name TopBottomFadeMask

@export var top_fade_height: int = 16
@export var bottom_fade_height: int = 16

@export var fill_color: Color = Color.WHITE
@export var fade_to_color: Color = Color.TRANSPARENT

var _mask_texture: ImageTexture

func _ready() -> void:
	if ThemeManager.current_theme.has("collection_options"):
		var options = ThemeManager.current_theme["collection_options"]
		top_fade_height = options["list_top_fade"]
		bottom_fade_height = options["list_bottom_fade"]
	_update_mask()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_update_mask")

func _update_mask() -> void:
	if size.x <= 0 or size.y <= 0:
		return

	var w := int(size.x)
	var h := int(size.y)

	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fill_color)

	# -------------------
	# Top fade
	# -------------------
	for y in range(min(top_fade_height, h)):
		var t := float(y) / float(max(top_fade_height - 1, 1))
		var fade_color := fade_to_color.lerp(fill_color, t)
		# starts transparent → becomes solid

		for x in range(w):
			img.set_pixel(x, y, fade_color)

	# -------------------
	# Bottom fade
	# -------------------
	var start_y = max(h - bottom_fade_height, 0)

	for y in range(min(bottom_fade_height, h)):
		var t := float(y) / float(max(bottom_fade_height - 1, 1))
		var fade_color := fill_color.lerp(fade_to_color, t)
		# starts solid → becomes transparent

		var yy = start_y + y
		if yy >= h:
			continue

		for x in range(w):
			img.set_pixel(x, yy, fade_color)

	# -------------------
	# Apply texture
	# -------------------
	if _mask_texture == null:
		_mask_texture = ImageTexture.create_from_image(img)
	else:
		_mask_texture.update(img)

	texture = _mask_texture
