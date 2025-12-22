extends MarginContainer


func setup():
	pass
	
func _ready():
	await get_tree().process_frame
	%PageLabel.grab_focus()

func render_ui():
	pass
	
func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.new_nav_back()
