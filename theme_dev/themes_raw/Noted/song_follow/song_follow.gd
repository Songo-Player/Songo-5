extends MarginContainer
## Shown at the foot of other pages while music plays: a sticky note strip
## with a tiny polaroid of the cover, the song in handwriting, and the
## buttons for getting back to it or stopping it, boxed in pencil.

const Squiggle = preload("../assets/squiggle.gd")

func _ready() -> void:
	for label in find_children("*", "Label", true, false):
		label.material = Squiggle.material(0.15)

func setup_display_for(music_record: TagLibMusicRecord) -> void:
	%SongTitle.set_carousel_text("%s - %s" % [music_record.title, music_record.artist])
	%Polaroid.show_texture(Artwork.song_cover_texture(music_record))
