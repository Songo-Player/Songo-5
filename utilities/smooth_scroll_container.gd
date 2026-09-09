extends ScrollContainer
class_name SmoothScrollContainer
## Smooth drag-to-scroll (mouse + touch) with inertia, for Godot 4.3.
##
## Attach this script directly to any ScrollContainer node. No other setup
## needed — it works with the container's existing children.
##
## How it works:
## - Press and drag (mouse or touch) inside the container to scroll it.
## - A small drag_threshold lets normal clicks on children (buttons, etc.)
##   still pass through if you didn't actually move the pointer much.
## - On release, the last measured drag velocity keeps scrolling and
##   decays over time (friction), giving a "flick to scroll" feel.

@export var drag_enabled: bool = true
@export_range(0.0, 0.999, 0.001) var friction: float = 0.96 ## higher = slides further after release
@export var min_velocity: float = 20.0   ## px/sec below which momentum stops
@export var drag_threshold: float = 8.0  ## px of movement before a press becomes a drag
@export var scroll_multiplier: float = 1.0

var _dragging: bool = false
var _captured: bool = false        # true once movement has exceeded drag_threshold
var _pointer_index: int = -999     # -1 = mouse, >=0 = touch index
var _press_pos: Vector2
var _last_pos: Vector2
var _last_time: int = 0
var _velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_process(true)

func _gui_input(event: InputEvent) -> void:
	if not drag_enabled:
		return

	if event is InputEventScreenTouch:
		_on_press_release(event.pressed, event.position, event.index)
	elif event is InputEventScreenDrag:
		_on_drag(event.position, event.index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_on_press_release(event.pressed, event.position, -1)
	elif event is InputEventMouseMotion and _dragging and _pointer_index == -1:
		_on_drag(event.position, -1)


func _on_press_release(pressed: bool, pos: Vector2, index: int) -> void:
	if pressed:
		_dragging = true
		_captured = false
		_pointer_index = index
		_press_pos = pos
		_last_pos = pos
		_last_time = Time.get_ticks_usec()
		_velocity = Vector2.ZERO
	else:
		if _dragging and _pointer_index == index:
			_dragging = false
		_captured = false


func _on_drag(pos: Vector2, index: int) -> void:
	if not _dragging or _pointer_index != index:
		return

	if not _captured:
		if _press_pos.distance_to(pos) > drag_threshold:
			_captured = true
			_cancel_pending_button_press()
			get_viewport().gui_release_focus()
		else:
			return

	var now: int = Time.get_ticks_usec()
	var dt: float = max((now - _last_time) / 1_000_000.0, 0.0001)
	var delta: Vector2 = pos - _last_pos

	scroll_horizontal -= int(delta.x * scroll_multiplier)
	scroll_vertical -= int(delta.y * scroll_multiplier)

	_velocity = delta / dt
	_last_pos = pos
	_last_time = now

	accept_event() # swallow so children don't also react while actively dragging


func _cancel_pending_button_press() -> void:
	# Once a drag is confirmed, cancel whatever button the press started on
	# so it doesn't fire its "pressed" signal on release. Toggling `disabled`
	# clears BaseButton's internal press-attempt state without affecting
	# normal clicks, since this only runs after drag_threshold is exceeded.
	var hovered: Control = get_viewport().gui_get_hovered_control()
	if hovered is BaseButton and not hovered.disabled:
		hovered.disabled = true
		await get_tree().process_frame
		hovered.disabled = false


func _process(delta: float) -> void:
	if _velocity != Vector2.ZERO and get_viewport().gui_get_focus_owner() != null:
		# Keep stripping focus for the whole duration of the drag, in case
		# something the pointer moves over tries to grab it mid-drag.
		get_viewport().gui_release_focus()

	if _dragging or _velocity.length() < min_velocity:
		if not _dragging:
			_velocity = Vector2.ZERO
		return

	scroll_horizontal -= int(_velocity.x * delta)
	scroll_vertical -= int(_velocity.y * delta)

	_velocity *= pow(friction, delta * 60.0) # frame-rate independent decay
