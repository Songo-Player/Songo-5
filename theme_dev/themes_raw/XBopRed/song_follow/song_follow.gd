extends MarginContainer

		
func setup_display_for(music_record: TagLibMusicRecord):
	var song_title = "%s ~ %s" % [music_record.title, music_record.artist]
	%SongTitle.set_carousel_text(song_title)
