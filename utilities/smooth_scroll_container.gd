extends ScrollContainer
class_name SmoothScrollContainer

@export var drag_enabled: bool = true
@export_range(0.0, 0.999, 0.001) var friction: float = 0.96 ## higher = slides further after release
@export var min_velocity: float = 20.0   
@export var drag_threshold: float = 8.0  
@export var scroll_multiplier: float = 1.01


@export var focus_search_root: NodePath

var _dragging: bool = false
var _captured: bool = false    
var _pointer_index: int = -999  
var _press_pos: Vector2
var _last_pos: Vector2
var _last_time: int = 0
var _velocity: Vector2 = Vector2.ZERO

var _v_scroll_bar: VScrollBar


func _ready() -> void:
	set_process(true)
	_setup_scrollbar_focus()


func _setup_scrollbar_focus() -> void:
	_v_scroll_bar = get_v_scroll_bar()
	_v_scroll_bar.focus_mode = Control.FOCUS_ALL

	_v_scroll_bar.focus_neighbor_bottom = _v_scroll_bar.get_path()
	_v_scroll_bar.focus_neighbor_top = _v_scroll_bar.get_path()

	var normal_grabber = _v_scroll_bar.get_theme_stylebox("grabber")
	var focused_grabber_style = _v_scroll_bar.get_theme_stylebox("grabber_pressed")

	_v_scroll_bar.focus_entered.connect(func():
		_v_scroll_bar.add_theme_stylebox_override("grabber", focused_grabber_style)
	)
	_v_scroll_bar.focus_exited.connect(func():
		_v_scroll_bar.add_theme_stylebox_override("grabber", normal_grabber)
	)

	_v_scroll_bar.gui_input.connect(_on_v_scroll_bar_gui_input)

	scroll_vertical_custom_step = 20


func _on_v_scroll_bar_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		var target := _find_closest_left_control()
		if target:
			target.grab_focus()
			_v_scroll_bar.accept_event()
	
func _find_closest_left_control() -> Control:
	var scrollbar_center_y := _get_grabber_center_y()
	var scrollbar_left_x := _v_scroll_bar.global_position.x

	var search_root: Node = get_node_or_null(focus_search_root)
	if search_root == null:
		search_root = get_tree().root

	var best_control: Control = null
	var best_distance := INF

	for control in _collect_focusable(search_root):
		if control == _v_scroll_bar:
			continue
		# Only consider controls whose center is to the left of the scrollbar.
		var control_center_x := control.global_position.x + control.size.x * 0.5
		if control_center_x >= scrollbar_left_x:
			continue

		var control_center_y := control.global_position.y + control.size.y * 0.5
		var distance = abs(control_center_y - scrollbar_center_y)
		if distance < best_distance:
			best_distance = distance
			best_control = control

	return best_control


func _get_grabber_center_y() -> float:
	var track_top := _v_scroll_bar.global_position.y
	var track_height := _v_scroll_bar.size.y

	var scrollable_range: float = (_v_scroll_bar.max_value - _v_scroll_bar.page) - _v_scroll_bar.min_value


	var range_span: float = _v_scroll_bar.max_value - _v_scroll_bar.min_value
	var grabber_size_ratio: float = 1.0
	if range_span > 0.0:
		grabber_size_ratio = clamp(_v_scroll_bar.page / range_span, 0.0, 1.0)
	var grabber_height: float = track_height * grabber_size_ratio

	var grabber_offset: float = 0.0
	if scrollable_range > 0.0:
		var value_ratio: float = (_v_scroll_bar.value - _v_scroll_bar.min_value) / scrollable_range
		grabber_offset = value_ratio * (track_height - grabber_height)

	return track_top + grabber_offset + grabber_height * 0.5


func _collect_focusable(root: Node) -> Array[Control]:
	var result: Array[Control] = []
	for child in root.get_children():
		if child is Control:
			var c := child as Control
			if c.focus_mode != Control.FOCUS_NONE and c.is_visible_in_tree():
				result.append(c)
		if child.get_child_count() > 0:
			result.append_array(_collect_focusable(child))
	return result


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
	var hovered: Control = get_viewport().gui_get_hovered_control()
	if hovered is BaseButton and not hovered.disabled:
		hovered.disabled = true
		await get_tree().process_frame
		hovered.disabled = false


func _process(delta: float) -> void:
	if _velocity != Vector2.ZERO and get_viewport().gui_get_focus_owner() != null:
		get_viewport().gui_release_focus()

	if _dragging or _velocity.length() < min_velocity:
		if not _dragging:
			_velocity = Vector2.ZERO
		return

	scroll_horizontal -= int(_velocity.x * delta)
	scroll_vertical -= int(_velocity.y * delta)

	_velocity *= pow(friction, delta * 60.0) # frame-rate independent decay
