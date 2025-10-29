extends VBoxContainer

class_name AllSongsContainer

var songo_data = SongoDataResource.get_instance()
var sfx_player
var songo_player
var music_records
var album
var artist
	
func setup(music_records_arg: Array[MusicRecord], songo_player_arg, sfx_player_arg):
	music_records = music_records_arg
	songo_player = songo_player_arg
	sfx_player = sfx_player_arg
	songo_player.music_files = music_records
	
	%SongsListLabel.text = "All Songs"
	await %VirtualizedList.ready
	%VirtualizedList.setup(music_records, "res://scenes/all_songs_container/song_button.tscn")
	%SongCount.text = "%d Total" % music_records.size()
	%ShuffleButton.grab_focus()
	
func set_as_album(album_arg):
	album = album_arg
	%CustomSongListImage.show()
	%SongsListLabel.text = album.name
	var image = album.cover
	if image: %CustomSongListImage.texture = ImageTexture.create_from_image(image)

func set_as_artist(artist_arg):
	artist = artist_arg
	%CustomSongListImage.show()
	%SongsListLabel.text = artist.name
	var image = artist.artist_image
	if image: %CustomSongListImage.texture = ImageTexture.create_from_image(image)

func render_ui():
	pass

func handle_input(delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.nav_back()
	
	if Input.is_action_pressed("x"):
		kick_off_shuffle()
		
	if Input.is_action_just_pressed("ui_accept"):
		var focused_button = get_viewport().gui_get_focus_owner()
		if focused_button.has_meta("music_record_index"):
			var target_index = focused_button.get_meta("music_record_index")
			Controller.songs_panel(music_records, target_index, "Playing")
		
func kick_off_shuffle():
	var shuffled_music = music_records.duplicate()
	shuffled_music.shuffle()
	print(shuffled_music[0].title)
	Controller.songs_panel(shuffled_music, 0, "Shuffle Play")

func truncate_with_ellipsis(text: String, limit: int) -> String:
	if text.length() <= limit:
		return text
	return text.substr(0, limit) + "…"
	
func _on_shuffle_button_pressed() -> void:
	kick_off_shuffle()
