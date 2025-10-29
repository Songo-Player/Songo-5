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
var spacer_top: Control
var spacer_bottom: Control
var item_pool: Array[Control] = []

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
	item_height = first_item.get_combined_minimum_size().y
	
	await get_tree().process_frame
	visible_item_count = int(size.y/item_height)+5
	
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

func scroll_to_item(index: int):
	if item_height > 0:
		var target_scroll = index * item_height
		scroll_vertical = int(target_scroll)
		
func _on_focus_changed(item: Control):
	if scroll_vertical < top_scroll_deadzone:
		scroll_vertical = 0
	
