extends MarginContainer

var songo_settings = SongoSettings.get_instance()
var tween

var icons = [
	load("res://assets/music.svg"),
	load("res://assets/record.svg"),
	load("res://assets/user.svg"),
	load("res://assets/layergroup.svg"),
	load("res://assets/gear.svg"),
	load("res://assets/exit_walk.svg"),
]
var glow_icons = [
	load("res://assets/music_glow.png"),
	load("res://assets/record_glow.png"),
	load("res://assets/user_glow.png"),
	load("res://assets/layer_group_glow.png"),
	load("res://assets/gear_glow.png"),
	load("res://assets/exit_walk_glow.png"),
]

func _ready():
	var nodes = %ButtonContainer.get_children()
	for i in nodes.size():
		var child = nodes[i]
		var button = child.get_child(0).get_child(0)
		button.focus_entered.connect(func():
			%FocusedIndicator.rotation = child.rotation
			%MenuIcon.texture = icons[i]
			%MenuIcon2.texture = glow_icons[i]
			)
	%AllSongsButton.grab_focus()
	_start_flicker()
	_on_theme_settings_updated()
	ThemeManager.theme_settings_updated.connect(_on_theme_settings_updated)
	
func _start_flicker() -> void:
	tween = create_tween().set_loops()
	tween.tween_property(%MenuIcon2, "modulate:a", 0.8, 1.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(%MenuIcon2, "modulate:a", 2.0, 1.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _process(delta):
	pass
	
	#var new_scale = 1.0/songo_settings.ui_scale
	#%ScaleControl.scale = Vector2(new_scale, new_scale)

func _on_settings_button_pressed() -> void:
	Controller.settings_index()

func _on_all_songs_button_pressed() -> void:
	Controller.songs_index()

func _on_albums_button_pressed() -> void:
	Controller.albums_index()

func _on_artists_button_pressed() -> void:
	Controller.artists_index()

func _on_playlists_button_pressed() -> void:
	Controller.playlists_index()

func _on_exit_button_pressed() -> void:
	Controller.quit_songo()
	
func _on_theme_settings_updated():
	var content_scale = ThemeManager.settings["content_scale"]
	%ScaleControl.scale = Vector2(content_scale, content_scale)
	pass
