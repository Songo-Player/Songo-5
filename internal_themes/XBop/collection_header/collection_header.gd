extends MarginContainer

var tween
var icons = [
	load("res://assets/music.svg"),
	load("res://assets/record.svg"),
	load("res://assets/user.svg"),
	load("res://assets/layergroup.svg"),

]
var glow_icons = [
	load("res://assets/music_glow.png"),
	load("res://assets/record_glow.png"),
	load("res://assets/user_glow.png"),
	load("res://assets/layer_group_glow.png"),
]

var _custom_image_texture
var custom_image_texture:
	set(value):
		%CustomImage.texture = value
		%CustomImage.show()
		#%DefaultImage.hide()

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
		
func setup(sort_key):
	%CollectionLabel.text = CollectionHelper.collection_name
	record_count = CollectionHelper.collection_size
	show_sort_info(sort_key)
	var image_texture = CollectionHelper.collection_image_texture
	var collection_type = CollectionHelper.collection_type
	var default_img_index = 0
	if "ALBUM" in collection_type: default_img_index = 1
	elif "ARTIST" in collection_type: default_img_index = 2
	elif "PLAYLIST" in collection_type: default_img_index = 3
	else: default_img_index = 0
	%DefaultIcon.texture = icons[default_img_index]
	%DefaultIcon2.texture = glow_icons[default_img_index]
	_start_flicker()
	
	if image_texture:
		custom_image_texture = image_texture

func show_sort_info(sort_key):
	var new_text = SongoSort.TYPES[sort_key]
	var dir_text = " (ASC)"
	if "_desc" in sort_key: dir_text = " (DESC)"
	UiHelper.flash_message(new_text + dir_text)

func _start_flicker() -> void:
	tween = create_tween().set_loops()
	tween.tween_property(%DefaultIcon2, "modulate:a", 0.8, 1.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(%DefaultIcon2, "modulate:a", 2.0, 1.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
