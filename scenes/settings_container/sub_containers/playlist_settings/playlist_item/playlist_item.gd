extends HBoxContainer

signal removed_playlist
var playlist: M3uCollection
var songo_data = SongoDataResource.get_instance()

func setup(playlist_arg: M3uCollection):
	playlist = playlist_arg
	$Name.text = playlist_arg.name
	$SongCount.text = "%d Songs" % playlist.music_records.size()

func _on_button_pressed() -> void:
	songo_data.playlists.erase(playlist)
	DirAccess.remove_absolute(playlist.m3u_path) 
	removed_playlist.emit()
