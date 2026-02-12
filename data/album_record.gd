class_name AlbumRecord extends Resource

@export var name: String
#@export var cover_path: String
@export var artists: Array[String]
@export var music_records: Array[MusicRecord]
@export var asset_id: String = ""

var img_path:
	get: return _get_album_image_path()
	
var cover:
	get: 
		if name == "Unknown Album" || _get_album_image_path() == "": return null
		var image = Image.new()
		image.load(_get_album_image_path())
		return image
		
func _get_album_image_path():
	var base_path = "user://album_images"
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
	
static func merge_albums(existing_albums: Array[AlbumRecord], new_albums: Array[AlbumRecord]) -> Array[AlbumRecord]:
	var album_map := {}

	for album in existing_albums:
		album_map[album.name] = album

	for new_album in new_albums:
		if album_map.has(new_album.name):
			var existing_album = album_map[new_album.name]

			for artist in new_album.artists:
				if artist not in existing_album.artists:
					existing_album.artists.append(artist)
			for record in new_album.music_records:
				if record not in existing_album.music_records:
					existing_album.music_records.append(record)
		else:
			album_map[new_album.name] = new_album
			
	var result: Array[AlbumRecord]
	result.assign(album_map.values())
	return result
	
func build_asset():
	var cleaned := name.strip_edges().replace(" ", "_")
	var regex := RegEx.new()
	regex.compile("[^A-Za-z0-9_]")
	var safe_name := regex.sub(cleaned, "", true)
	if safe_name.length() > 3:
		asset_id = safe_name
	else:
		asset_id = "defaulted_id_%d" % name.hash()
		
func set_dicebear_image():
	var save_path := "user://album_images/%s.svg" % asset_id

	var dir := DirAccess.open("user://")
	if dir.dir_exists("album_images") and FileAccess.file_exists(save_path):
		return false

	if not dir.dir_exists("album_images"):
		dir.make_dir("album_images")
		
	var source_img_path = "res://assets/dicebear/rings/rings-%d.svg" % randi_range(0, 499)
	
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
