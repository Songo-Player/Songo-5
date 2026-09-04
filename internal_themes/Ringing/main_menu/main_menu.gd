extends MarginContainer

@export var rotation_tween_duration: float = 0.4
@export var rotation_transition: Tween.TransitionType = Tween.TRANS_CUBIC
@export var rotation_ease: Tween.EaseType = Tween.EASE_OUT

var menu_item_inner_rotate = []
var menu_item_placement_rotation = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	menu_item_inner_rotate = [
		%AllSongsInnerRotate, #0
		%AlbumsInnerRotate, #-60
		%ArtistsInnerRotate, #-120
		%PlaylistsInnerRotate, #-180
		%SettingsInnerRotate, #-240
		%ExitInnerRotate #-300
	]
	
	for menu_item in menu_item_inner_rotate:
		menu_item_placement_rotation.append(menu_item.get_parent().rotation_degrees)
	
	await get_tree().process_frame
	%AllSongsButton.grab_focus()

func _process(delta: float) -> void:
	for i in menu_item_inner_rotate.size():
		var menu_item = menu_item_inner_rotate[i]
		menu_item.rotation_degrees = -%MainMenuContainer.rotation_degrees - menu_item_placement_rotation[i]


func _on_exit_button_pressed() -> void:
	Controller.quit_songo()

func _on_all_songs_button_pressed() -> void:
	Controller.songs_index()

func _on_albums_button_pressed() -> void:
	Controller.albums_index()

func _on_artists_button_pressed() -> void:
	Controller.artists_index()

func _on_playlists_button_pressed() -> void:
	Controller.playlists_index()

func _on_settings_button_pressed() -> void:
	Controller.settings_index()



var _rotation_tween: Tween

func _rotate_menu_to(degrees: float) -> void:
	var current: float = %MainMenuContainer.rotation_degrees
	# Find the shortest equivalent angle to rotate to, avoiding a full 360 spin
	var delta: float = fposmod(degrees - current + 180.0, 360.0) - 180.0
	var target: float = current + delta

	if _rotation_tween:
		_rotation_tween.kill()
	_rotation_tween = create_tween()
	_rotation_tween.set_trans(rotation_transition)
	_rotation_tween.set_ease(rotation_ease)
	_rotation_tween.tween_property(%MainMenuContainer, "rotation_degrees", target, rotation_tween_duration)


func _on_all_songs_button_focus_entered() -> void:
	_rotate_menu_to(0)

func _on_albums_button_focus_entered() -> void:
	_rotate_menu_to(-60)

func _on_artists_button_focus_entered() -> void:
	_rotate_menu_to(-120)

func _on_playlists_button_focus_entered() -> void:
	_rotate_menu_to(-180)

func _on_settings_button_focus_entered() -> void:
	_rotate_menu_to(-240)

func _on_exit_button_focus_entered() -> void:
	_rotate_menu_to(-300)
