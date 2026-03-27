extends ScrollContainer
class_name VirtualizedList
# Configuration
@export var top_scroll_deadzone: float  = 5.0
@export var vbox: VBoxContainer
@export var focus_first_item: bool = true

# Data
var visible_item_count: int = 1
var first_visible_index: int = 0
var item_height: float = 0.0
var data_items = []
var item_scene_path = ""
var total_items: int: 
	get: return data_items.size()
# Nodes
#var vbox: VBoxContainer
var v_scroll_bar
var spacer_top: Control
var spacer_bottom: Control
var item_pool: Array[Control] = []
var focused_item
var focused_index

static var item_heights = {}

func setup(data_items_arg, item_scene_path_arg):
	if data_items_arg.size() == 0: return
	data_items = data_items_arg
	item_scene_path = item_scene_path_arg
	
	# Setup scroll container
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	if vbox == null:
		# Create VBox container
		vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(vbox)
		
	vbox.add_theme_constant_override("separation", 0)
	
	# Create top spacer
	spacer_top = Control.new()
	spacer_top.custom_minimum_size.y = 0
	vbox.add_child(spacer_top)
	
	# Create first item to measure height
	var first_item = create_item()
	item_pool.append(first_item)
	vbox.add_child(first_item)
	update_item_content(first_item, 0)
	
	# Create bottom spacer
	spacer_bottom = Control.new()
	spacer_bottom.custom_minimum_size.y = 0
	vbox.add_child(spacer_bottom)
	
	# Measure the first item's height
	item_height = item_heights.get(item_scene_path, 0.0)
	if item_height == 0.0:
		item_height = first_item.get_combined_minimum_size().y
		item_heights[item_scene_path] = item_height
	#print(UiHelper.main_color_panel.size.y)
	#await get_tree().process_frame
	#visible_item_count = int(size.y/item_height)+5
	visible_item_count = int(UiHelper.main_color_panel.size.y/item_height)+5
	# Now create the rest of the items
	for i in range(1, visible_item_count):
		var item = create_item()
		item_pool.append(item)
		vbox.add_child(item)
		vbox.move_child(item, vbox.get_child_count() - 2)  # Before bottom spacer

	# Initial update
	update_spacers()
	update_visible_items()
		
	# Connect scroll event
	get_v_scroll_bar().value_changed.connect(_on_scroll_changed)
	if focus_first_item: focus_first()
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	v_scroll_bar = get_v_scroll_bar()
	v_scroll_bar.focus_mode = Control.FOCUS_ALL
	
	v_scroll_bar.focus_neighbor_bottom = v_scroll_bar.get_path()
	v_scroll_bar.focus_neighbor_top = v_scroll_bar.get_path()
	
	var normal_grabber = v_scroll_bar.get_theme_stylebox("grabber")
	var focused_grabber = normal_grabber.duplicate()
	focused_grabber.bg_color = Color("8d0000")
	v_scroll_bar.focus_entered.connect(func(): 
		v_scroll_bar.add_theme_stylebox_override("grabber", focused_grabber)
	)
	v_scroll_bar.focus_exited.connect(func(): 
		v_scroll_bar.add_theme_stylebox_override("grabber", normal_grabber)
	)
	scroll_vertical_custom_step = (item_height*data_items.size())/50.0
	
func focus_first():
	if item_pool.is_empty():
		return

	var root = item_pool[0]
	var focus_target = _find_first_focusable(root)
	if focus_target:
		focus_target.grab_focus()

func _find_first_focusable(node: Node) -> Control:
	if node is Control and node.focus_mode != Control.FOCUS_NONE:
		return node

	for child in node.get_children():
		var found = _find_first_focusable(child)
		if found:
			return found

	return null
	
func create_item() -> Control:
	return load(item_scene_path).instantiate()

func update_item_content(item: Control, index: int):
	item.setup(data_items[index], index)
	if (index == data_items.size()-1) && "setup_last_item" in item:
		item.setup_last_item()
	#item.set_meta("item_index", index)

func update_spacers():
	# Calculate spacer heights
	var top_height = first_visible_index * item_height
	var visible_height = visible_item_count * item_height
	var total_height = total_items * item_height
	var bottom_height = max(0, total_height - top_height - visible_height)
	
	if is_instance_valid(spacer_top):
		spacer_top.custom_minimum_size.y = top_height
	if is_instance_valid(spacer_bottom):
		spacer_bottom.custom_minimum_size.y = bottom_height

func update_visible_items():
	# Update content of all visible items
	for i in range(visible_item_count):
		var data_index = first_visible_index + i
		if data_index < total_items:
			item_pool[i].visible = true
			update_item_content(item_pool[i], data_index)
		else:
			item_pool[i].visible = false

func _on_scroll_changed(value: float):
	if item_height <= 0:
		return
		
	var new_first_index = int(value / item_height) - 2
	new_first_index = clamp(new_first_index, 0, max(0, total_items - visible_item_count))
	
	if new_first_index == first_visible_index:
		return
	
	var diff = new_first_index - first_visible_index
	
	# Handle large jumps (fast scroll)
	if abs(diff) >= visible_item_count:
		first_visible_index = new_first_index
		update_spacers()
		update_visible_items()
		return
	
	# Scrolling down
	if diff > 0:
		for i in range(diff):
			var moved_item = item_pool.pop_front()
			item_pool.append(moved_item)
			vbox.move_child(moved_item, vbox.get_child_count() - 2)
			
			var new_index = first_visible_index + visible_item_count + i
			update_item_content(moved_item, new_index)
	
	# Scrolling up
	elif diff < 0:
		for i in range(abs(diff)):
			var moved_item = item_pool.pop_back()
			item_pool.insert(0, moved_item)
			vbox.move_child(moved_item, 1)
			
			var new_index = first_visible_index - 1 - i
			update_item_content(moved_item, new_index)
	
	first_visible_index = new_first_index
	update_spacers()
		
func _on_focus_changed(item: Control):
	if is_inside_tree():
		if item.has_meta("item_index") && data_items.size() > item.get_meta("item_index"):
			focused_index = item.get_meta("item_index")
			focused_item = data_items[focused_index]	
		else:
			focused_index = null
			focused_item = null
	
	if scroll_vertical < top_scroll_deadzone:
		scroll_vertical = 0
		
func refresh():
	UiHelper.fire_focus_next()
	update_spacers()
	update_visible_items()
	_on_scroll_changed(scroll_vertical)
		
func remove_focused_item():
	if focused_item == null:
		return
	
	# If list is now empty, clear everything
	if data_items.is_empty():
		focused_item = null
		for item in item_pool:
			item.visible = false
		update_spacers()
		return

	# Determine new focus index (stay at same position, or last item if at end)
	var new_focus_index = min(focused_index, data_items.size() - 1)
	
	# Check if we need to adjust first_visible_index
	if first_visible_index >= data_items.size():
		first_visible_index = max(0, data_items.size() - visible_item_count)
	
	# Update spacers with new total count
	update_spacers()
	
	# Update all visible items
	for i in range(item_pool.size()):
		var data_index = first_visible_index + i
		if data_index < total_items:
			item_pool[i].visible = true
			update_item_content(item_pool[i], data_index)
		else:
			item_pool[i].visible = false

	_on_scroll_changed(scroll_vertical)
	# Restore focus to the appropriate item
	if Controller.active_container is SongPanelContainer: return
	
	#await get_tree().process_frame
	for item in item_pool:
		if item.visible and item.get_meta("item_index") == new_focus_index:
			if "set_focus" in item:
				item.set_focus()
			else:
				var focus_target = _find_first_focusable(item)
				if focus_target:
					focus_target.grab_focus()
			break
			
	# Update focused_item reference
	focused_item = data_items[new_focus_index]
	focused_index = new_focus_index
	
#func remove_data_item(item):
#	print("WEOIRDS")
#	var index = data_items.find(item)
#	if index == -1:
#		return  # Item not found
#	
#	# Remove the item from data
#	data_items.erase(item)
#	
#	# If we removed an item before the visible area, adjust first_visible_index
#	if index < first_visible_index:
#		first_visible_index = max(0, first_visible_index - 1)
#	
#	# Clamp first_visible_index to valid range
#	first_visible_index = clamp(first_visible_index, 0, max(0, total_items - visible_item_count))
#	
#	# Update the display
#	update_spacers()
#	_on_scroll_changed(scroll_vertical)
#	#update_visible_items()
#	#for i in range(item_pool.size()):
#	#	if item_pool[i].get_meta("item_index") == index:
#	#		item_pool[i].hide()
	#	pass
	
	# Adjust scroll position if needed
#	if first_visible_index * item_height < scroll_vertical:
#		scroll_vertical = first_visible_index * item_height
