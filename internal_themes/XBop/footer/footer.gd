extends MarginContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%VersionLabel.text = SongoDataResource.VERSION
	_update_nav_bar()
	Controller.page_changed.connect(_update_nav_bar)

func _update_nav_bar():
	%NavLabel.text = " > ".join(Controller.nav_label)
