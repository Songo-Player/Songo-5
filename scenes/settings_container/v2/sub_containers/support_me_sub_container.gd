extends MarginContainer

func setup():
	pass
	
func _ready():
	await get_tree().process_frame
	%PageLabel.grab_focus()
	$ScrollContainer.scroll_vertical = 0

func render_ui():
	pass
	
func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.new_nav_back()

func _on_roadmap_items_focus_entered() -> void:
	$ScrollContainer.scroll_vertical = 9999
