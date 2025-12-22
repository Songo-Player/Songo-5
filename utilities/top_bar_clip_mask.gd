extends TextureRect
class_name TopBarClipMask

@export var mask_height: int = 8
@export var mask_left_margin: int = 40
@export var mask_color: Color = Color.TRANSPARENT  # color of the hidden strip (transparent)
@export var fill_color: Color = Color.WHITE        # fill color for visible parts
@export var bottom_fade_height: int = 20           # height of the bottom fade

var _mask_texture: ImageTexture

func _ready():
	_update_mask()
	
func _notification(what):
	if what == NOTIFICATION_RESIZED:
		call_deferred("_update_mask")

func _update_mask():
	if size.x <= 0 or size.y <= 0:
		return
	
	# Create an empty image for the mask texture
	var img := Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	img.fill(fill_color)

	# Draw the top transparent strip (your original mask)
	for y in range(mask_height):
		for x in range(mask_left_margin, int(size.x)):
			img.set_pixel(x, y, mask_color)

	# Draw the bottom fade
	var start_y = int(size.y) - bottom_fade_height
	for y in range(bottom_fade_height):
		var alpha = float(y) / float(bottom_fade_height)  # 0.0 at top, 1.0 at bottom
		var fade_color = fill_color.lerp(mask_color, alpha)
		for x in range(int(size.x)):
			img.set_pixel(x, start_y + y, fade_color)

	# Convert to ImageTexture and apply it
	if not _mask_texture:
		_mask_texture = ImageTexture.create_from_image(img)
	else:
		_mask_texture.update(img)

	texture = _mask_texture
