extends RefCounted
class_name PluginCollection

## A named list a plugin can hand to Controller.collection_list(), e.g. a list
## of radio stations. Items render with the theme's collection button; items
## with an activate() method call it when pressed instead of opening a list.

var name: String
var music_records: Array

func _init(name_arg: String = "", items: Array = []) -> void:
	name = name_arg
	music_records = items
