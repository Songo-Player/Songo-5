@tool
extends PanelContainer

enum DEFAULT_TYPE {SONG, ARTIST, ALBUM, PLAYLIST, SETTING}
var _default_type: DEFAULT_TYPE = DEFAULT_TYPE.SONG


var _collection_label
var collection_label:
	set(value):
		_collection_label = value
		%CollectionLabel.text = value
	get(): return _collection_label	

		
var sort_label_key:
	set(value):
		fade_sort_label(value)
		
func setup(sort_key):
	%CollectionLabel.text = CollectionHelper.collection_name
	if sort_key:
		fade_sort_label(sort_key)
	else:
		%SortTypeContainer.hide()

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
		func(value): %SortTypeContainer.add_theme_constant_override("margin_right", value),
		0, -offset, 0.15
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


	tween.tween_callback(func():
		label.text = new_text
		label.modulate.a = 0.0
		%SortTypeContainer.add_theme_constant_override("margin_right", offset)
		%SortAscImg.hide()
		%SortDescImg.hide()
		if "_asc" in sort_key: %SortAscImg.show()
		if "_desc" in sort_key: %SortDescImg.show()
	)

	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_method(
		func(value): %SortTypeContainer.add_theme_constant_override("margin_right", value),
		offset, 0, 0.3
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
