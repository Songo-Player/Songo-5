extends TextureRect
class_name TopBottomFadeMask

# Fade heights come from the CollectionOptions theme type (list_top_fade,
# list_bottom_fade); defaults are in songo_base_theme.tres.
var top_fade_height: int = 0
var bottom_fade_height: int = 16

@export var fill_color: Color = Color.WHITE
@export var fade_to_color: Color = Color.TRANSPARENT

var _mask_texture: ImageTexture

func _ready() -> void:
	_read_theme_fades()
	_update_mask()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_update_mask")
	elif what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_read_theme_fades()
		call_deferred("_update_mask")

func _read_theme_fades() -> void:
	top_fade_height = get_theme_constant("list_top_fade", "CollectionOptions")
	bottom_fade_height = get_theme_constant("list_bottom_fade", "CollectionOptions")

func _update_mask() -> void:
	if size.x <= 0 or size.y <= 0:
		return

	var w := int(size.x)
	var h := int(size.y)

	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
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
	# update() only takes an image of the texture's own size.
	if _mask_texture == null or Vector2i(_mask_texture.get_size()) != Vector2i(w, h):
		_mask_texture = ImageTexture.create_from_image(img)
	else:
		_mask_texture.update(img)

	texture = _mask_texture
