extends MarginContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func setup(sort_key):
	show_sort_info(sort_key)

func show_sort_info(sort_key):
	if sort_key:
		var new_text = SongoSort.TYPES[sort_key]
		var dir_text = " (ASC)"
		if "_desc" in sort_key: dir_text = " (DESC)"
		UiHelper.flash_message(new_text + dir_text)
