class_name MusicRecord extends Resource

@export var full_path: String
@export var title: String
@export var raw_length: float
@export var album: String
@export var artist: String

var length: String:
	get: return formatted_duration(raw_length)
	
func formatted_duration(length_sec: float):
	var minutes: int = int(length_sec) / 60
	var seconds: int = int(length_sec) % 60
	return "%d:%02d" % [minutes, seconds]
