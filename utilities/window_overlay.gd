extends Window

class_name OverlayWindow

# Windows ignore anchors and parent transforms, so this mirrors the parent
# (TransformContainer) by hand: the window covers the whole screen, its canvas
# gets the parent's on-screen transform (incl. UiHelper.apply_rotation's
# CanvasLayer rotation), and child Controls are laid out at the parent's size.
var _parent_control: Control
var _fit_queued := false

func _ready() -> void:
	_parent_control = get_parent() as Control
	if _parent_control == null:
		push_warning("OverlayWindow: parent isn't a Control, can't fit to it")
		return
	# apply_rotation() sets the size before the rotation, so resized fires
	# mid-update; defer the fit until it's done.
	_parent_control.resized.connect(_queue_fit)
	get_tree().root.size_changed.connect(_queue_fit)
	_queue_fit()

# Nearest CanvasLayer above the parent (the main UI's), however deep we're nested.
func _find_canvas_layer() -> CanvasLayer:
	var node := _parent_control.get_parent()
	while node != null && node is not CanvasLayer:
		node = node.get_parent()
	return node as CanvasLayer

func _queue_fit() -> void:
	if _fit_queued: return
	_fit_queued = true
	_fit_to_parent.call_deferred()

func _fit_to_parent() -> void:
	_fit_queued = false
	var root := get_tree().root
	var logical_size := root.get_visible_rect().size
	if logical_size.x <= 0: return
	# The root's stretch (window size + UI scale) also scales embedded windows'
	# rects, so a logical-size window gets upscaled (blurry). Instead render the
	# window at physical size and cancel the stretch for it with a 1/s global
	# canvas transform. That also hits the main UI's CanvasLayer, so the layer
	# gets an x s scale back and ends up drawn exactly as before.
	var s := float(root.size.x) / logical_size.x
	root.global_canvas_transform = Transform2D.IDENTITY.scaled(Vector2.ONE / s)
	var layer := _find_canvas_layer()
	if layer: layer.scale = Vector2(s, s)
	else: push_warning("OverlayWindow: no CanvasLayer above parent, main UI will draw at 1/s")

	position = Vector2i.ZERO
	size = root.size
	# Contents stay laid out in logical units like the main UI.
	content_scale_factor = s
	# Parent's on-screen transform (rotation/offset from apply_rotation) minus
	# the layer's x s, which content_scale_factor already covers.
	canvas_transform = _parent_control.get_global_transform_with_canvas().scaled(Vector2.ONE / s)
	for child in get_children():
		if child is Control:
			child.set_anchors_preset(Control.PRESET_TOP_LEFT)
			child.position = Vector2.ZERO
			child.size = _parent_control.size
