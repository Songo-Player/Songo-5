extends VBoxContainer

class_name AllSongsContainer

signal closing_container
signal opening_song_panel(play_type)

var songo_data = SongoDataResource.get_instance()
var sfx_player
var songo_player
var mp3_records

	
func setup(songo_player_arg: SongoPlayer, sfx_player_arg: AudioStreamPlayer):
	mp3_records = songo_data.mp3_records
	songo_player = songo_player_arg
	sfx_player = sfx_player_arg
	songo_player.mp3_files = mp3_records.map(func(r: Mp3Record): return r.full_path)

	%ShuffleButton.get_child(0).pressed.connect(_on_shuffle_button_pressed)
	apply_color_to_hide_panels()
	call_deferred("focus_shuffle_button")
	build_list()

func render_ui():
	%ShuffleButton.visible = %SongItemList.get_v_scroll_bar().value == 0
	%ItemListTopHide.visible = %SongItemList.get_v_scroll_bar().value != 0
	%HideBottom.visible = not %SongItemList.scrolled_to_bottom()

	
func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		closing_container.emit()
	
	if Input.is_action_pressed("x"):
		kick_off_shuffle()
		
	if Input.is_action_just_pressed("primary"):
		var selected_items = %SongItemList.get_selected_items()
		if selected_items: play_song(selected_items[0])
		
func apply_color_to_hide_panels():
	var style = %ItemListTopHide.get_theme_stylebox("panel").duplicate()
	style.bg_color = songo_data.theme_color
	%ItemListTopHide.add_theme_stylebox_override("panel", style)

func kick_off_shuffle():
	var shuffled_mp3s = mp3_records.duplicate()
	shuffled_mp3s.shuffle()
	songo_player.mp3_files = shuffled_mp3s.map(func(r: Mp3Record): return r.full_path)
	songo_player.play_index = 0
	opening_song_panel.emit("Shuffle Play")
		
func build_list():
	var batch_size = 25

	for i in mp3_records.size():
		%SongItemList.add_item(mp3_records[i].title, load("res://assets/music.svg"))
		%SongItemList.set_item_metadata(i, mp3_records[i].length)
		if i % batch_size == 0:
			%SongCount.text = "%d Total" % (i+1)
			await Engine.get_main_loop().process_frame

	%SongCount.text = "%d Total" % mp3_records.size()
	
func play_song(play_index: int):
	songo_player.play_index = play_index
	opening_song_panel.emit("Playing")
	
func focus_shuffle_button():
	%ShuffleButton.get_child(0).grab_focus()

func _on_shuffle_button_pressed() -> void:
	kick_off_shuffle()

func _on_song_item_list_item_selected(index: int) -> void:
	sfx_player.play_nav_sfx()

func _on_song_item_list_focus_entered() -> void:
	%SongItemList.select(0)

func _on_song_item_list_focus_exited() -> void:
	if is_instance_valid(%SongItemList): %SongItemList.deselect_all()
