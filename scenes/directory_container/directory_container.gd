extends VBoxContainer

class_name DirectoryContainer

var path_array = []
var importing: bool = false
var songo_data = SongoDataResource.get_instance()
var virtualized_list
var dark_out

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%MusicDirTip.text = DeviceOS.music_dir_tip
	
func setup(dark_out_arg: Control):
	dark_out = dark_out_arg
	set_initial_path()
	var initial_directories = get_children_directories("".join(path_array))
	await %VirtualizedList.ready
	virtualized_list = %VirtualizedList
	virtualized_list.setup(initial_directories, "res://scenes/directory_container/directory_button.tscn")
	display_current_path()

func get_children_directories(path):
	var results = []
	var dir_access := DirAccess.open(path)
	if dir_access:
		dir_access.list_dir_begin()
		var entry_name = dir_access.get_next()
		while entry_name != "":
			if dir_access.current_is_dir():
				results.append(entry_name)
			entry_name = dir_access.get_next()
		dir_access.list_dir_end()
	return results
	
func render_ui():
	%ImportProgressContainer.visible = importing
	if importing:
		if songo_data.import_step == 0:
			%ImportProgressLabel.text = "MP3's found %d" % int(songo_data.import_progress)
			%ProgressBar.visible = false
			%ImportStepLabel.text = "Step 1/3 Finding audio files"
		if songo_data.import_step == 1:
			%ProgressBar.visible = true
			%ImportProgressLabel.text = "Progress %.1f%%" % (clamp(songo_data.import_progress, 0, 1.0) * 100)
			%ProgressBar.scale.x = clamp(songo_data.import_progress, 0, 1.0)
			%ImportStepLabel.text = "Step 2/3 Indexing audio files"
		if songo_data.import_step == 2:
			%ProgressBar.visible = true
			%ImportProgressLabel.text = "Progress %.1f%%" % (clamp(songo_data.import_progress, 0, 1.0) * 100)
			%ProgressBar.scale.x = clamp(songo_data.import_progress, 0, 1.0)
			%ImportStepLabel.text = "Step 3/3 Building Album Covers"
		
func handle_input(delta: float):
	if importing == true: return
	
	if Input.is_action_just_pressed("back"):
		if path_array.size() == 1:
			Controller.nav_back()
		else:
			path_array.pop_back()
			enter_dir()
	
	if Input.is_action_just_pressed("ui_accept"):
		var focused_button = get_viewport().gui_get_focus_owner()
		var target_dir = focused_button.get_meta("dir_path")
		if target_dir: enter_dir(target_dir)
		else: _on_select_directory_button_pressed()
	
func set_initial_path():
	var root_path: String

	match OS.get_name():
		"Windows":
			root_path = OS.get_environment("SystemDrive") + "/"
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "macOS":
			root_path = "/"
		_:
			root_path = "/"
	path_array.append(root_path)

func display_current_path():
	var path = "".join(path_array)
	%ParentDirectoryLabel.text = path
	if path_array.size() == 1:
		%ParentDirectoryLabel.text = path + " (root)"
	call_deferred("focus_first_directory")
		
func focus_first_directory():
	var select_dir_node = virtualized_list.find_child("SelectDirectoryButton", true, false)
	select_dir_node.grab_focus()
	
func enter_dir(dir_name = null):
	if dir_name != null: path_array.append(dir_name)
	
	if path_array.size() == 1:
		%DirectoryInfoContainer.show()
	else:
		%DirectoryInfoContainer.hide()
		
	var child_directories = get_children_directories("".join(path_array))
	virtualized_list.queue_free()
	await get_tree().process_frame
	virtualized_list = load("res://scenes/directory_container/virtualized_list_directories.tscn").instantiate()
	%ListVbox.add_child(virtualized_list)
	virtualized_list.setup(child_directories, "res://scenes/directory_container/directory_button.tscn")
	display_current_path()
	

func _on_select_directory_button_pressed() -> void:
	importing = true
	dark_out.show()
	var path = "".join(path_array)
	print("SELECTING: ", path)
	
	songo_data.music_directory_path = path
	songo_data.save()
	await get_tree().process_frame
	
	songo_data.index_mp3s()
	await songo_data.import_finished
	dark_out.hide()
	Controller.nav_back()
