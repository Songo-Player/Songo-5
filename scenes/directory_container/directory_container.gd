extends VBoxContainer

class_name DirectoryContainer

var path_array = []
var importing: bool = false
var songo_data = SongoDataResource.get_instance()
var virtualized_list

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var music_dir_tip_text := "I suggest making a 'MUSIC' folder next to 'ROMS'."
	
	var env_tip := OS.get_environment("SONGO_DIR_TIP")
	if env_tip != null and env_tip.strip_edges() != "":
		music_dir_tip_text = env_tip
	
	%MusicDirTip.text = music_dir_tip_text
	
func setup(path_array_arg = []):
	path_array = path_array_arg
	if path_array == []: set_initial_path()
	var initial_directories = get_children_directories("".join(path_array))
	await %VirtualizedList.ready
	virtualized_list = %VirtualizedList
	virtualized_list.setup(initial_directories, "res://scenes/directory_container/directory_button.tscn")
	display_current_path()
	if path_array.size() == 1:
		%DirectoryInfoContainer.show()
	else:
		%DirectoryInfoContainer.hide()
	var select_dir_button = virtualized_list.find_child("SelectDirectoryButton", true)
	select_dir_button.pressed.connect(_on_select_directory_button_pressed)

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
		
	results.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
	return results
	
func render_ui():
	%ImportProgressContainer.visible = importing
	if importing:
		if songo_data.import_step == 0:
			%ImportProgressLabel.text = "Files found %d" % int(songo_data.import_progress)
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
		Controller.new_nav_back()
	
	return
	if Input.is_action_just_pressed("ui_accept"):
		var focused_button = get_viewport().gui_get_focus_owner()
		var target_dir = focused_button.get_meta("dir_path")
		if target_dir: 
			#path_array.append(target_dir)
			var new_path = path_array.duplicate()
			new_path.append(target_dir)
			Controller.settings_directory_select(new_path)
			#enter_dir(target_dir)
		#else: _on_select_directory_button_pressed()
	
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
	
func reimport():
	importing = true
	UiHelper.dark_out.show()
	songo_data.index_mp3s()
	await songo_data.import_finished
	UiHelper.dark_out.hide()
	Controller.nav_back_to_settings()
	
func _on_select_directory_button_pressed() -> void:
	if path_array.size() == 1:
		UiHelper.app_message.show_message("Cannot select root directory.")
		return
		
	var path = "".join(path_array)
	if songo_data.add_music_directory_path(path):
		importing = true
		UiHelper.dark_out.show()
		songo_data.save()
		await get_tree().process_frame
		songo_data.index_mp3s()
		await songo_data.import_finished
		UiHelper.dark_out.hide()
		Controller.nav_back_to_settings()
	else:
		var message = songo_data.path_error
		if (message == null || message == ""): message = "Unknown Error"
		UiHelper.app_message.show_message(message)
