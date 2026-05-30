extends MarginContainer

var index
@onready var virtualized_list = Controller.active_container.virtualized_list

func setup_last_item():
	%ButtonSeparator.hide()
	
func set_focus():
	%Button.grab_focus()
	
func _process(delta: float) -> void:
	%TheTail.visible = is_control_in_scroll_zone(self, virtualized_list)
		
func is_control_in_scroll_zone(control: Control, scroll: ScrollContainer) -> bool:
	var visible_rect := scroll.get_global_rect()
	var control_rect := control.get_global_rect()
	
	var control_top := control_rect.position.y
	var visible_top := visible_rect.position.y
	
	return control_top >= visible_top
	
func setup(music_record, index_arg):
	index = index_arg
	if %ButtonSeparator.visible == false: %ButtonSeparator.show()
	if Controller.nav_label.has("Albums"):
		%SongName.text = music_record.title_with_track
	else:
		%SongName.text = music_record.title
		
	%Duration.text = music_record.length
	%Button.set_meta("item_index", index)

	
	if !%Button.pressed.is_connected(_song_button_pressed):
		%Button.pressed.connect(_song_button_pressed)
	
func _song_button_pressed():
	var current_page = Controller.active_container
	if "music_records" in current_page:
		Controller.songs_panel(current_page.music_records, index)

func _on_button_mouse_entered() -> void:
	%Button.grab_focus()
