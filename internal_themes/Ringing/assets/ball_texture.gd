extends RefCounted

## A white circle the visualizers tint and scale for each ball. Unlike
## draw_circle, whose polygons each cost a draw call, textured rects batch. Draw
## with a canvas item using TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, so that small
## balls stay smooth.

const TEXTURE_SIZE := 64
const EDGE_RADIUS := TEXTURE_SIZE * 0.5 - 1.0 # 1px gap so the edge can fade out
const RECT_SCALE := TEXTURE_SIZE * 0.5 / EDGE_RADIUS

static var _texture: ImageTexture

static func draw(canvas: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	var half_size := Vector2.ONE * radius * RECT_SCALE
	canvas.draw_texture_rect(_get_texture(), Rect2(pos - half_size, half_size * 2.0), false, color)

static func _get_texture() -> ImageTexture:
	if _texture == null:
		_texture = _build_texture()
	return _texture

static func _build_texture() -> ImageTexture:
	var data := PackedByteArray()
	data.resize(TEXTURE_SIZE * TEXTURE_SIZE * 4)
	data.fill(255)

	var center := Vector2.ONE * (TEXTURE_SIZE - 1) * 0.5
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var distance := Vector2(x, y).distance_to(center)
			var alpha := clampf(EDGE_RADIUS + 0.5 - distance, 0.0, 1.0)
			data[(y * TEXTURE_SIZE + x) * 4 + 3] = int(alpha * 255.0)

	var image := Image.create_from_data(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8, data)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
