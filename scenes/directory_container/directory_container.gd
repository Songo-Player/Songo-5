extends VBoxContainer

class_name DirectoryContainer

signal selected_dir(path)
signal closing_container

var path_array = []
var importing: bool = false
var songo_data = SongoDataResource.get_instance()
var dark_out

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func setup(dark_out_arg: Control):
	dark_out = dark_out_arg
	set_initial_path()
	build_list()

func render_ui():
	%ImportProgressContainer.visible = importing
	if importing:
		%ImportProgressLabel.text = "Progress %.1f%%" % (songo_data.import_progress * 100)
		%ProgressBar.scale.x = songo_data.import_progress
		
func handle_input(delta: float):
	if importing == true: return
	
	if Input.is_action_just_pressed("back"):
		if path_array.size() == 1:
			closing_container.emit()
		else:
			path_array.pop_back()
			clear_and_rebuild_list()
		
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

func build_list():
	var path = "".join(path_array)
	%ParentDirectoryLabel.text = path
	if path_array.size() == 1:
		%ParentDirectoryLabel.text = path + " (root)"
	build_children_directory_display(path)


func build_children_directory_display(path):
	var dir_access := DirAccess.open(path)
	if dir_access:
		var select_button = load("res://scenes/directory_container/select_directory_button.tscn").instantiate()
		%DirectoryChildren.add_child(select_button)
		select_button.pressed.connect(_select_current_dir)
		dir_access.list_dir_begin()
		var entry_name = dir_access.get_next()
		while entry_name != "":
			if dir_access.current_is_dir():
				var full_path = dir_access.get_current_dir().path_join(entry_name)
				var button = load("res://scenes/directory_container/directory_button.tscn").instantiate()
				button.text = "/" + entry_name
				%DirectoryChildren.add_child(button)
				button.pressed.connect(func(): enter_dir(entry_name + "/"))
			entry_name = dir_access.get_next()
		dir_access.list_dir_end()
	call_deferred("focus_first_directory")
	if path_array.size() == 1:
		%DirectoryInfoContainer.show()
	else:
		%DirectoryInfoContainer.hide()

func focus_first_directory():
	var children = %DirectoryChildren.get_children()
	if children.size() > 0: children[0].grab_focus()
	%ScrollContainer.scroll_vertical = 0
	
func enter_dir(dir_name):
	path_array.append(dir_name)
	clear_and_rebuild_list()

func clear_and_rebuild_list():
	for child in %DirectoryChildren.get_children():
		child.queue_free()
	await get_tree().process_frame
	call_deferred("build_list")
	
func _on_enter_dir(path):
	enter_dir(path)

func _select_current_dir():
	importing = true
	dark_out.show()
	print("SELECTING: ", "".join(path_array))
	selected_dir.emit("".join(path_array))
