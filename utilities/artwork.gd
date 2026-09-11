extends Node

# Artwork resolution for the TagLib* metadata records, which carry no image
# data of their own. Covers what the old MusicRecord/AlbumRecord/ArtistRecord
# computed properties used to do:
#   - resolving user:// cover files by asset_id
#   - the per-song "album cover texture" (folder image, then embedded art)
#   - generating dicebear placeholder art
#
# Registered as the `Artwork` autoload.

const _IMAGE_EXTS := ["png", "svg", "webp", "jpeg", "jpg"]

var _song_cover_cache := {}

func _ready() -> void:
	# Album images can be (re)generated during an import, so drop cached song
	# covers when one finishes.
	SongoDataResource.get_instance().import_finished.connect(clear_song_cover_cache)

func clear_song_cover_cache() -> void:
	_song_cover_cache.clear()

# --- path resolution (was AlbumRecord/ArtistRecord._get_*_image_path) ---------

func album_image_path(asset_id: String) -> String:
	return _resolve_image("user://album_images", asset_id)

func artist_image_path(asset_id: String) -> String:
	return _resolve_image("user://artist_images", asset_id)

func _resolve_image(base_dir: String, asset_id: String) -> String:
	if asset_id == "":
		return ""
	for ext in _IMAGE_EXTS:
		var override_path := "%s/%s-override.%s" % [base_dir, asset_id, ext]
		if FileAccess.file_exists(override_path):
			return override_path
	for ext in _IMAGE_EXTS:
		var path := "%s/%s.%s" % [base_dir, asset_id, ext]
		if FileAccess.file_exists(path):
			return path
	return ""

# --- Image loaders (was AlbumRecord.cover / ArtistRecord.artist_image) --------

func album_cover(album: TagLibAlbumRecord) -> Image:
	if album == null or album.name == "Unknown Album":
		return null
	return _load_image(album_image_path(album.asset_id))

func artist_image(artist: TagLibArtistRecord) -> Image:
	if artist == null:
		return null
	return _load_image(artist_image_path(artist.asset_id))

func _load_image(path: String) -> Image:
	if path == "":
		return null
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return image

# --- Per-song cover texture (was MusicRecord.album_cover_texture + injection) -

# Folder-level album art first (user://album_images via the album record),
# then the file's embedded cover. Cached by full_path.
func song_cover_texture(record: TagLibMusicRecord) -> Texture2D:
	if record == null:
		return null
	if _song_cover_cache.has(record.full_path):
		return _song_cover_cache[record.full_path]

	var texture: Texture2D = null
	var album_img: Image = SongoDataResource.get_instance().get_album_cover(record.album)
	if album_img != null:
		texture = ImageTexture.create_from_image(album_img)
	if texture == null:
		texture = GDTagLib.get_cover_image(record.full_path)

	_song_cover_cache[record.full_path] = texture
	return texture

# --- Dicebear placeholders (was AlbumRecord/ArtistRecord.set_dicebear_image) --

func ensure_dicebear(asset_id: String, kind: String) -> bool:
	if asset_id == "":
		return false

	var dir_name := "album_images" if kind == "album" else "artist_images"
	var save_path := "user://%s/%s.svg" % [dir_name, asset_id]

	var dir := DirAccess.open("user://")
	if dir.dir_exists(dir_name) and FileAccess.file_exists(save_path):
		return false
	if not dir.dir_exists(dir_name):
		dir.make_dir(dir_name)

	var source_path: String
	if kind == "album":
		source_path = "res://assets/dicebear/rings/rings-%d.svg" % randi_range(0, 499)
	else:
		source_path = "res://assets/dicebear/bottts-neutral/botttsNeutral-%d.svg" % randi_range(0, 999)

	if not FileAccess.file_exists(source_path):
		print("Trying to load non-existant image: %s" % source_path)
		return false

	var src := FileAccess.open(source_path, FileAccess.READ)
	var data := src.get_buffer(src.get_length())
	src.close()

	var dst := FileAccess.open(save_path, FileAccess.WRITE)
	dst.store_buffer(data)
	dst.close()
	return true
