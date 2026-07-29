extends MarginContainer

signal subsonic_album_selected(album: Dictionary)
signal subsonic_song_selected(song: Dictionary, index: int)

var current_view: String = "albums"
var albums: Array = []
var songs: Array = []
var subsonic_connected: bool = false

func setup():
	pass

func _ready():
	await get_tree().process_frame
	_check_connection()
	%AlbumsBtn.grab_focus()

func _check_connection():
	subsonic_connected = SubsonicManager and SubsonicManager.connected
	if not subsonic_connected:
		%NoConnectionLabel.show()
		%ContentPage.hide()
		%ConnectSettingsBtn.grab_focus()
		return
	%NoConnectionLabel.hide()
	%ContentPage.show()
	_load_albums()

func _load_albums():
	%LoadingLabel.show()
	%AlbumsList.hide()
	%AlbumsBtn.grab_focus()

	var all_albums: Array = []
	var page_size = 500
	var offset = 0
	while true:
		var result = SubsonicManager.get_album_list("alphabeticalByName", page_size, offset)
		if not result.get("ok", false):
			break
		var data = result.get("data", [])
		var page = data if data is Array else data.get("album", [])
		if page.is_empty():
			break
		for a in page:
			all_albums.append(a)
		if page.size() < page_size:
			break
		offset += page_size

	albums = all_albums
	%LoadingLabel.hide()
	_build_albums_list()

func _build_albums_list():
	for child in %AlbumsList.get_children():
		child.queue_free()

	if albums.is_empty():
		%AlbumsList.hide()
		%EmptyLabel.show()
		return

	%EmptyLabel.hide()
	%AlbumsList.show()

	for i in range(albums.size()):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 40)
		btn.size_flags_horizontal = 3
		var a = albums[i]
		var year = a.get("year", 0)
		var year_str = " (%d)" % year if year > 0 else ""
		btn.text = "%s — %s%s" % [a.get("name", "Unknown"), a.get("artist_name", "Unknown"), year_str]
		btn.connect("pressed", Callable(self, "_on_album_pressed").bind(i))
		btn.connect("mouse_entered", Callable(btn, "grab_focus"))
		%AlbumsList.add_child(btn)

	await get_tree().process_frame
	if %AlbumsList.get_child_count() > 0:
		%AlbumsList.get_child(0).grab_focus()

func _on_album_pressed(index: int):
	if index < 0 or index >= albums.size():
		return
	var album = albums[index]
	var result = SubsonicManager.get_album(album.get("id", ""))
	if result.get("ok", false):
		var album_data = result.get("data", {})
		var entries = album_data.get("entries", [])
		if entries.size() > 0:
			var typed: Array[Dictionary] = []
			for e in entries:
				typed.append(e)
			SubsonicAudioManager.set_queue(typed, 0)
			UiHelper.flash_message("Playing: %s" % album.get("name", "Unknown"))

func render_ui():
	pass

func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.nav_back()
		return

func _on_connect_settings_btn_pressed():
	Controller.settings_subsonic()
