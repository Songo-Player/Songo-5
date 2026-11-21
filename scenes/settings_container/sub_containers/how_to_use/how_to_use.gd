extends MarginContainer

func setup():
	pass

func _ready():
	# Same check the quick menu uses to offer "Quit with Music"
	%BackgroundPlay.visible = SongoPlayer.bg_play_enabled()
	_setup_sub_section_toggles()
	await get_tree().process_frame
	%ScrollContainer.get_v_scroll_bar().grab_focus()
	%ScrollContainer.scroll_vertical = 0

func render_ui():
	pass

func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.nav_back()

## Every Controls sub-section with a Header/ToggleButton shows/hides its Content.
## Whether one starts open is set by Content's visibility in the scene.
func _setup_sub_section_toggles():
	var buttons: Array[Button] = []
	for sub_section in %SubSections.get_children():
		var button = sub_section.get_node_or_null("MarginContainer/VBox/Header/ToggleButton")
		var content = sub_section.get_node_or_null("MarginContainer/VBox/Content")
		if button == null or content == null: continue
		button.pressed.connect(func():
			content.visible = not content.visible
			button.text = "Hide" if content.visible else "Show"
		)
		buttons.append(button)

	# Moving up off the first button or down off the last goes back to the scroll bar
	if buttons.is_empty(): return
	var scroll_bar_path = %ScrollContainer.get_v_scroll_bar().get_path()
	buttons.front().focus_neighbor_top = scroll_bar_path
	buttons.back().focus_neighbor_bottom = scroll_bar_path
