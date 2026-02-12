class_name ArtistRecord extends Resource

@export var name: String = "Unknown Artist"
@export var music_records: Array[MusicRecord]
@export var asset_id: String = ""

var img_path:
	get:
		return _get_artist_image_path()
		
var artist_image:
	get: 
		var image_path = _get_artist_image_path()
		if image_path != "":	
			var image = Image.new()
			image.load(image_path)
			return image
		
		
func _get_artist_image_path():
	var base_path = "user://artist_images"
	var image_extensions = ["png", "svg", "webp", "jpeg", "jpg"]
		
	for ext in image_extensions:
		var potential_path = "%s/%s-override.%s" % [base_path, asset_id, ext]
		if FileAccess.file_exists(potential_path):
			return potential_path
			
	for ext in image_extensions:
		var potential_path = "%s/%s.%s" % [base_path, asset_id, ext]
		if FileAccess.file_exists(potential_path):
			return potential_path
			
	return ""
				
		
static func merge_artists(existing_artists: Array[ArtistRecord], new_artists: Array[ArtistRecord]) -> Array[ArtistRecord]:
	var artist_map := {}

	for artist in existing_artists:
		artist_map[artist.name] = artist

	for new_artist in new_artists:
		if artist_map.has(new_artist.name):
			var existing_artist = artist_map[new_artist.name]
			for record in new_artist.music_records:
				if record not in existing_artist.music_records:
					existing_artist.music_records.append(record)	
		else:
			artist_map[new_artist.name] = new_artist
	var result: Array[ArtistRecord]	
	result.assign(artist_map.values())
	return result
	
func set_dicebear_image():
	var save_path := "user://artist_images/%s.svg" % asset_id

	var dir := DirAccess.open("user://")
	if dir.dir_exists("artist_images") and FileAccess.file_exists(save_path):
		return false

	if not dir.dir_exists("artist_images"):
		dir.make_dir("artist_images")
		
	var source_img_path = "res://assets/dicebear/bottts-neutral/botttsNeutral-%d.svg" % randi_range(0, 999)
	
	if not FileAccess.file_exists(source_img_path):
		print("Trying to load non-existant image: %s" % source_img_path)
		return false

	var src := FileAccess.open(source_img_path, FileAccess.READ)
	var data := src.get_buffer(src.get_length())
	src.close()

	var dst := FileAccess.open(save_path, FileAccess.WRITE)
	dst.store_buffer(data)
	dst.close()

	return true

func build_asset():
	var cleaned := name.strip_edges().replace(" ", "_")
	var regex := RegEx.new()
	regex.compile("[^A-Za-z0-9_]")
	var safe_name := regex.sub(cleaned, "", true)
	if safe_name.length() > 3:
		asset_id = safe_name
	else:
		asset_id = "defaulted_id_%d" % name.hash()
	
	set_dicebear_image()
