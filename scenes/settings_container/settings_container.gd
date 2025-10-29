extends VBoxContainer

class_name SettingsContainer

#@onready var songo_data = SongoDataResource.get_instance()
func setup():
	#artists = artists_arg
	%VersionLabel.text = SongoDataResource.VERSION
	
func render_ui():
	pass
	
func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.nav_back()
		
	if Input.is_action_just_pressed("ui_accept"):
		pass
		#var focused_button = get_viewport().gui_get_focus_owner()
		#var target_artist = artists[focused_button.get_meta("artist_index")]
		#Controller.artist_songs_index(target_artist)
