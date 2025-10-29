extends RefCounted
class_name Mp3ImageExtractor

## Extracts embedded album art (ID3v2.3 / ID3v2.4 APIC frame) from an MP3 file.
## Returns a Godot Image if found, or null if not.

## Extracts embedded album art (ID3v2.3 / ID3v2.4 APIC frame) from an MP3 file.
## Returns a Godot Image if found, or null if not.

func get_cover_imageOLD(mp3_path: String) -> Image:
	var file := FileAccess.open(mp3_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open file: %s" % mp3_path)
		return null

	# Verify "ID3" header
	var b1 := file.get_8()
	var b2 := file.get_8()
	var b3 := file.get_8()
	if b1 != 0x49 or b2 != 0x44 or b3 != 0x33: # 'I', 'D', '3'
		file.close()
		return null

	var version_major := file.get_8() # 3 = v2.3, 4 = v2.4
	var version_minor := file.get_8()
	var flags := file.get_8()
	var tag_size := _syncsafe_to_int(file.get_buffer(4))

	var tag_data := file.get_buffer(tag_size)
	file.close()

	var offset := 0
	while offset + 10 <= tag_data.size():
		var frame_id := tag_data.slice(offset, offset + 4).get_string_from_utf8()
		var frame_size := _frame_size(tag_data, offset + 4, version_major)
		if frame_size <= 0 or offset + 10 + frame_size > tag_data.size():
			break

		if frame_id == "APIC":
			var frame_bytes := tag_data.slice(offset + 10, offset + 10 + frame_size)
			return _parse_apic_frame(frame_bytes)

		offset += 10 + frame_size

	return null


# ------------------ Internal helpers ------------------

func _syncsafe_to_intOLD(bytes: PackedByteArray) -> int:
	if bytes.size() != 4:
		return 0
	return (bytes[0] << 21) | (bytes[1] << 14) | (bytes[2] << 7) | bytes[3]

func _frame_sizeOLD(data: PackedByteArray, offset: int, version_major: int) -> int:
	var b := data.slice(offset, offset + 4)
	if b.size() < 4:
		return 0
	if version_major == 4:
		return _syncsafe_to_int(b)
	else:
		return (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]

func _parse_apic_frameOLD(frame_data: PackedByteArray) -> Image:
	var idx := 0
	if frame_data.size() < 10:
		return null

	# Text encoding byte (0 = ISO-8859-1, 1 = UTF-16)
	var encoding := frame_data[idx]
	idx += 1

	# MIME type string (null-terminated)
	var mime_end := frame_data.find(0, idx)
	if mime_end == -1:
		return null
	var mime := frame_data.slice(idx, mime_end).get_string_from_utf8()
	idx = mime_end + 1

	# Picture type byte
	idx += 1

	# Description (null-terminated)
	var desc_end := frame_data.find(0, idx)
	if desc_end == -1:
		return null
	idx = desc_end + 1

	# Remaining data is the actual image
	var image_data := frame_data.slice(idx, frame_data.size())

	var image := Image.new()
	var err := ERR_CANT_OPEN

	if "png" in mime:
		err = image.load_png_from_buffer(image_data)
	elif "jpeg" in mime or "jpg" in mime:
		err = image.load_jpg_from_buffer(image_data)
	elif "bmp" in mime:
		err = image.load_bmp_from_buffer(image_data)
	elif "gif" in mime:
		err = image.load_gif_from_buffer(image_data)

	if err != OK:
		push_error("Failed to load embedded image (MIME: %s)" % mime)
		return null

	return image
	
func get_cover_image(mp3_path: String) -> Image:
	var file := FileAccess.open(mp3_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open file: %s" % mp3_path)
		return null

	# Verify "ID3" header
	if file.get_8() != 0x49 or file.get_8() != 0x44 or file.get_8() != 0x33:
		file.close()
		return null

	var version_major := file.get_8() # 2 = v2.2, 3 = v2.3, 4 = v2.4
	var version_minor := file.get_8()
	var flags := file.get_8()
	var tag_size := _syncsafe_to_int(file.get_buffer(4))

	var tag_data := file.get_buffer(tag_size)
	file.close()

	var offset := 0
	while true:
		if version_major == 2:
			if offset + 6 > tag_data.size(): break
			var frame_id := tag_data.slice(offset, offset + 3).get_string_from_utf8()
			if frame_id == "": break
			var frame_size := (tag_data[offset + 3] << 16) | (tag_data[offset + 4] << 8) | tag_data[offset + 5]
			if frame_size <= 0 or offset + 6 + frame_size > tag_data.size(): break

			if frame_id == "PIC":
				var frame_bytes := tag_data.slice(offset + 6, offset + 6 + frame_size)
				return _parse_pic_frame_v22(frame_bytes)

			offset += 6 + frame_size
		else:
			if offset + 10 > tag_data.size(): break
			var frame_id := tag_data.slice(offset, offset + 4).get_string_from_utf8()
			if frame_id == "": break
			var frame_size := _frame_size(tag_data, offset + 4, version_major)
			if frame_size <= 0 or offset + 10 + frame_size > tag_data.size(): break

			if frame_id == "APIC":
				var frame_bytes := tag_data.slice(offset + 10, offset + 10 + frame_size)
				return _parse_apic_frame(frame_bytes)

			offset += 10 + frame_size

	return null


# ------------------ Internal helpers ------------------

func _syncsafe_to_int(bytes: PackedByteArray) -> int:
	if bytes.size() != 4:
		return 0
	return (bytes[0] << 21) | (bytes[1] << 14) | (bytes[2] << 7) | bytes[3]

func _frame_size(data: PackedByteArray, offset: int, version_major: int) -> int:
	var b := data.slice(offset, offset + 4)
	if b.size() < 4:
		return 0
	if version_major == 4:
		return _syncsafe_to_int(b)
	else:
		return (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]


# -------- Parse APIC (v2.3/v2.4) --------
func _parse_apic_frame(frame_data: PackedByteArray) -> Image:
	var idx := 0
	if frame_data.size() < 10:
		return null

	var encoding := frame_data[idx]
	idx += 1

	var mime_end := frame_data.find(0, idx)
	if mime_end == -1:
		return null
	var mime := frame_data.slice(idx, mime_end).get_string_from_utf8()
	idx = mime_end + 1

	idx += 1 # skip picture type

	var desc_end := frame_data.find(0, idx)
	if desc_end == -1:
		return null
	idx = desc_end + 1

	var image_data := frame_data.slice(idx, frame_data.size())
	return _load_image_from_data(image_data, mime)


# -------- Parse PIC (v2.2) --------
func _parse_pic_frame_v22(frame_data: PackedByteArray) -> Image:
	var idx := 0
	if frame_data.size() < 6:
		return null

	var encoding := frame_data[idx]
	idx += 1

	# 3-character image format (e.g. "JPG", "PNG")
	var format := frame_data.slice(idx, idx + 3).get_string_from_utf8().to_lower()
	idx += 3

	idx += 1 # skip picture type

	var desc_end := frame_data.find(0, idx)
	if desc_end == -1:
		return null
	idx = desc_end + 1

	var image_data := frame_data.slice(idx, frame_data.size())

	var mime := ""
	match format:
		"jpg", "jpeg":
			mime = "image/jpeg"
		"png":
			mime = "image/png"
		"bmp":
			mime = "image/bmp"
		"gif":
			mime = "image/gif"
		_:
			mime = "image/jpeg" # fallback

	return _load_image_from_data(image_data, mime)


# -------- Generic image loader --------
func _load_image_from_data(image_data: PackedByteArray, mime: String) -> Image:
	var image := Image.new()
	var err := ERR_CANT_OPEN

	if "png" in mime:
		err = image.load_png_from_buffer(image_data)
	elif "jpeg" in mime or "jpg" in mime:
		err = image.load_jpg_from_buffer(image_data)
	elif "bmp" in mime:
		err = image.load_bmp_from_buffer(image_data)
	elif "gif" in mime:
		err = image.load_gif_from_buffer(image_data)

	if err != OK:
		push_error("Failed to load embedded image (MIME: %s)" % mime)
		return null

	return image
