extends MarginContainer

func _ready() -> void:
	_apply_accent_color()
	ThemeManager.theme_settings_updated.connect(_apply_accent_color)

func _apply_accent_color() -> void:
	var accent = Color(ThemeManager.settings["accent_color"])
	var title_style = %TitlePanel.get_theme_stylebox("panel")
	if title_style: title_style.border_color = accent
	var stop_style = %StopMusicButton.get_theme_stylebox("normal")
	if stop_style: stop_style.border_color = accent
	var return_style = %ReturnToMusicButton.get_theme_stylebox("normal")
	if return_style: return_style.border_color = accent

func setup_display_for(music_record: TagLibMusicRecord):
	var song_title = "%s ~ %s" % [music_record.title, music_record.artist]
	%SongTitle.set_carousel_text(song_title)
