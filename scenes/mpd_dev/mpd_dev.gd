extends Control

# Dev-only entry point for the MPD server that does not depend on the
# TagLib GDExtension. Run with:
#
#   SONGO_MPD_MUSIC_DIRS=/path/to/music godot --path . res://scenes/mpd_dev/mpd_dev.tscn
#
# Library metadata comes from ffprobe (or filenames); playback goes through
# SongoPlayerV2 when the FFmpegPlayer extension is present, otherwise the
# server keeps a mock state.

func _ready() -> void:
	var folders: Array = MPDServer.scan_folders
	var text := "Songo-5 MPD dev server\n\n"
	text += "Listening: tcp/%d\n" % MPDServer.listen_port
	text += "Tracks: %d\n" % MPDServer.library.size()
	text += "Folders: %s\n" % (", ".join(PackedStringArray(folders)) if folders.size() > 0 else "(none - set SONGO_MPD_MUSIC_DIRS)")
	var p = MPDServer._player_node()
	text += "Player: %s\n" % ("SongoPlayerV2" if p != null else "mock (FFmpegPlayer extension not loaded)")
	$Label.text = text
	print(text)