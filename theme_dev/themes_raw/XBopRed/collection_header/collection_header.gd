extends MarginContainer

var tween
var icons = [
	preload("../assets/music.svg"),
	preload("../assets/record.svg"),
	preload("../assets/user.svg"),
	preload("../assets/layergroup.svg"),
	preload("../assets/gear.svg")
]
var glow_icons = [
	preload("../assets/music_glow.png"),
	preload("../assets/record_glow.png"),
	preload("../assets/user_glow.png"),
	preload("../assets/layer_group_glow.png"),
	preload("../assets/gear_glow.png")
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

func _ready() -> void:
	_apply_accent_color()
	ThemeManager.theme_settings_updated.connect(_apply_accent_color)

func _apply_accent_color() -> void:
	var accent = Color(ThemeManager.settings["accent_color"])
	for node in [%SortSpoke1, %SortSpoke2, %SortSpoke3, %SortSpoke4, %SortSpoke5]:
		node.modulate = Color(accent.r, accent.g, accent.b, node.modulate.a)
	%DefaultIcon2.modulate = Color(accent.r, accent.g, accent.b, %DefaultIcon2.modulate.a)
	var sort_style = %SortIndicator.get_theme_stylebox("panel")
	if sort_style: sort_style.border_color = accent

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
	elif "SETTING" in collection_type: default_img_index = 4
	else: default_img_index = 0
	%DefaultIcon.texture = icons[default_img_index]
	%DefaultIcon2.texture = glow_icons[default_img_index]
	_start_flicker()
	
	if image_texture:
		custom_image_texture = image_texture

func show_sort_info(sort_key):
	if sort_key is bool && sort_key == false:
		%SortIndicator.modulate.a = 0.0
		return
	
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
