@tool
extends Control
## A polaroid pinned to the page: a white frame with a soft shadow, the
## photo, and a handwritten caption in the wide bottom margin. Tilted a
## little; it lives in a plain Control so the tilt isn't undone by a
## container. Shows album or artist art when there is some, otherwise the
## default photo.

const P = preload("palette.gd")
const Squiggle = preload("squiggle.gd")
const FONT = preload("font_hand.tres")
const DEFAULT_PHOTO = preload("louis-hansel-M_dJ_ScwaLE-unsplash.jpg")

@export var photo_size := 130.0:
	set(value):
		photo_size = value
		_layout()
@export var tilt_degrees := -4.0:
	set(value):
		tilt_degrees = value
		_layout()
@export var caption_size := 18

var _frame: PanelContainer
var _style: StyleBoxFlat
var _photo: TextureRect
var _caption: Label
var _request := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = P.PAPER
	_style.shadow_color = Color(0, 0, 0, 0.3)
	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override("panel", _style)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(column)
	_photo = TextureRect.new()
	_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_photo.texture = DEFAULT_PHOTO
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_photo)
	_caption = Label.new()
	_caption.add_theme_font_override("font", FONT)
	_caption.add_theme_font_size_override("font_size", caption_size)
	_caption.add_theme_color_override("font_color", P.PENCIL)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_caption.material = Squiggle.material(0.2)
	column.add_child(_caption)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	if _frame == null: return
	# A polaroid's border scales with it, with the wide strip at the bottom
	# whether or not there's a caption written in it.
	var border := clampf(roundf(photo_size * 0.06), 3.0, 8.0)
	_style.content_margin_left = border
	_style.content_margin_right = border
	_style.content_margin_top = border
	_caption.visible = _caption.text != ""
	_style.content_margin_bottom = 2.0 if _caption.visible else roundf(border * 2.6)
	_style.shadow_size = int(clampf(photo_size * 0.05, 2.0, 6.0))
	_style.shadow_offset = Vector2(-1, 1) * clampf(photo_size * 0.015, 1.0, 2.0)
	_photo.custom_minimum_size = Vector2(photo_size, photo_size)
	_caption.custom_minimum_size = Vector2(photo_size, 0)
	_frame.size = _frame.get_combined_minimum_size()
	# Centred in this control, tilted about its middle.
	_frame.pivot_offset = _frame.size / 2.0
	_frame.position = ((size - _frame.size) / 2.0).floor()
	_frame.rotation_degrees = tilt_degrees

## The frame's size before tilting, for laying out around it.
func frame_size() -> Vector2:
	return _frame.get_combined_minimum_size() if _frame else Vector2.ZERO

## Shows the art for a song, album, artist or playlist (kind), or the
## default photo when there's none.
func show_record(kind: String, record, caption := "") -> void:
	# Pages often fill these in before they've entered the tree.
	if not is_node_ready(): await ready
	_caption.text = caption
	_layout()
	_request += 1
	var request := _request
	_photo.texture = DEFAULT_PHOTO
	if record == null or Engine.is_editor_hint(): return
	var path := ""
	match kind:
		"song":
			var cover = Artwork.song_cover_texture(record)
			if cover: _photo.texture = cover
			return
		"album": path = Artwork.album_image_path(record.asset_id)
		"artist": path = Artwork.artist_image_path(record.asset_id)
		"playlist": path = str(record.img_path) if record.img_path else ""
	if path == "" or not FileAccess.file_exists(path): return
	var loader = AsyncImageLoader.load_async(path)
	loader.image_loaded.connect(func(texture):
		# Only the latest request counts, if the menu moved on meanwhile.
		if request == _request and is_instance_valid(_photo) and texture:
			_photo.texture = texture
	)

## Shows a texture directly.
func show_texture(texture: Texture2D, caption := "") -> void:
	if not is_node_ready(): await ready
	_request += 1
	_caption.text = caption
	_layout()
	_photo.texture = texture if texture else DEFAULT_PHOTO
