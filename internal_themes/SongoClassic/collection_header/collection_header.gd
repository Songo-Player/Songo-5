@tool
extends PanelContainer

enum DEFAULT_TYPE {SONG, ARTIST, ALBUM, PLAYLIST, SETTING}
var _default_type: DEFAULT_TYPE = DEFAULT_TYPE.SONG
const DEFAULTS = [
	{
		"gradient": "res://shared_resources/all_songs_gradient_v2.tres",
		"image": "res://assets/music.svg"
	},
	{
		"gradient": "res://shared_resources/artists_gradient.tres",
		"image": "res://assets/user.svg"
	},
	{
		"gradient": "res://shared_resources/albums_gradient.tres",
		"image": "res://assets/record.svg"
	},
	{
		"gradient": "res://shared_resources/playlists_gradient.tres",
		"image": "res://assets/layergroup.svg"
	},
	{
		"gradient": "res://shared_resources/settings_gradient.tres",
		"image": "res://assets/gear.svg"
	},
]

@export var default_type: DEFAULT_TYPE = DEFAULT_TYPE.SONG:
	set(value):
		_default_type = value
		var style = load(DEFAULTS[_default_type]["gradient"])
		%CollectionImageContainer.add_theme_stylebox_override("panel", style)
		%DefaultImage.texture = load(DEFAULTS[_default_type]["image"])
	get(): return _default_type

var _custom_image_texture
var custom_image_texture:
	set(value):
		%CustomImage.texture = value
		%CustomImage.show()
		%DefaultImage.hide()

var _collection_label
var collection_label:
	set(value):
		_collection_label = value
		%CollectionLabel.text = value
	get(): return _collection_label
		
var _record_count := 0
var _count_tween: Tween

var record_count:
	set(value):
		# Kill existing tween so it doesn't stack
		if _count_tween and _count_tween.is_running():
			_count_tween.kill()
		
		var start = _record_count
		var target = value
		_record_count = value
		
		var duration := 1.0
		if value < 25: duration = 0.5
		
		_count_tween = create_tween()
		
		_count_tween.tween_method(
			func(v):
				var int_val := int(round(v))
				%RecordCount.text = "%d Total" % int_val,
			start, target, duration
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	get:
		return _record_count

		
var sort_label_key:
	set(value):
		fade_sort_label(value)
		
func setup(sort_key):
	%CollectionLabel.text = CollectionHelper.collection_name
	record_count = CollectionHelper.collection_size
	if sort_key:
		fade_sort_label(sort_key)
	else:
		%SortTypeContainer.hide()
	var image_texture = CollectionHelper.collection_image_texture
	var collection_type = CollectionHelper.collection_type
	if "ALBUM" in collection_type: default_type = DEFAULT_TYPE.ALBUM
	elif "ARTIST" in collection_type: default_type = DEFAULT_TYPE.ARTIST
	elif "PLAYLIST" in collection_type: default_type = DEFAULT_TYPE.PLAYLIST
	elif "SETTING" in collection_type:
		default_type = DEFAULT_TYPE.SETTING
		%SortControlIndicator.hide()
	else: default_type = DEFAULT_TYPE.SONG
	
	if image_texture:
		custom_image_texture = image_texture

func fade_sort_label(sort_key):
	var new_text = SongoSort.TYPES[sort_key]
	var label: Label = %SortTypeLabel
	
	if %SortTypeContainer.has_meta("tween"):
		var old_tween = %SortTypeContainer.get_meta("tween")
		if old_tween and old_tween.is_running(): old_tween.kill()
	
	var tween = create_tween()
	%SortTypeContainer.set_meta("tween", tween)
	var offset = 10

	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.15)
	tween.parallel().tween_method(
		func(value): %SortTypeContainer.add_theme_constant_override("margin_left", value),
		0, -offset, 0.15
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


	tween.tween_callback(func():
		label.text = new_text
		label.modulate.a = 0.0
		%SortTypeContainer.add_theme_constant_override("margin_left", offset)
		%SortAscImg.hide()
		%SortDescImg.hide()
		if "_asc" in sort_key: %SortAscImg.show()
		if "_desc" in sort_key: %SortDescImg.show()
	)

	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_method(
		func(value): %SortTypeContainer.add_theme_constant_override("margin_left", value),
		offset, 0, 0.3
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
