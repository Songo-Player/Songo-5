@tool
extends Control
## A paperclip holding something to the page: the back half of the clip is
## drawn behind the paper and the front half over it, so it really looks
## clipped on. Position and turn this control where the clip should sit.

const BACK = preload("paperclip_full.png")
const FRONT = preload("paperclip_half.png")

@export var color := Color(1, 0.17, 0.13):
	set(value):
		color = value
		modulate = value
@export var clip_size := Vector2(60, 30)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = color
	for part in [[BACK, -1], [FRONT, 1]]:
		var rect := TextureRect.new()
		rect.texture = part[0]
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Absolute z: the back half goes under the paper (z 0) but over the
		# graph paper background (z -2); the front half goes over everything.
		rect.z_as_relative = false
		rect.z_index = part[1]
		rect.size = clip_size
		rect.position = -clip_size / 2.0
		add_child(rect)
