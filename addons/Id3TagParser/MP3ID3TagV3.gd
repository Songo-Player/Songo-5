class_name MP3ID3TagV3

const TAG_HEADER_LENGTH: int = 10
const FRAME_HEADER_LENGTH: int = 10
const STRING_TERMINATOR = 0x00
const STRING_TERMINATOR_UTF = [0x00, 0x00]

var _ID3Header: ID3MainHeader
var _frames: Dictionary = {}
var _file_path: String
var bytesShift: int

# -------------------------------
# Inner classes
# -------------------------------

class ID3MainHeader:
	var isId3: bool
	var id3Ver: String
	var unsync: bool
	var compress: bool
	var size: int

# -------------------------------
# Properties
# -------------------------------

var file_path: String:
	set(value):
		_clear()
		_file_path = value
	get:
		return _file_path

var header: ID3MainHeader:
	get:
		if !_ID3Header:
			_ID3Header = _decode_head()
		return _ID3Header

var frames: Dictionary:
	get:
		if !_frames:
			_frames = _decode_frame_heads()
		return _frames

# -------------------------------
# Core decode helpers
# -------------------------------

func _clear() -> void:
	_file_path = ""
	_ID3Header = null
	_frames.clear()

func _decode_head() -> ID3MainHeader:
	if _file_path == "":
		return null

	var file = FileAccess.open(_file_path, FileAccess.READ)
	if not file:
		return null

	var header_bytes = file.get_buffer(TAG_HEADER_LENGTH)
	file.close()

	if header_bytes.size() < TAG_HEADER_LENGTH:
		return null

	var id3 := ""
	var verH := 0
	var verL := 0
	var flags := 0
	var size := 0

	for i in header_bytes.size():
		var cv = header_bytes[i]
		match i:
			0,1,2:
				id3 += char(cv)
			3:
				verH = cv
			4:
				verL = cv
			5:
				flags = cv
			_:
				size = ((size << 7) | cv)

	var is_valid := (id3 == "ID3" and verH < 0xFF and verL < 0xFF and size <= 0x1FFFFFFF)
	var header_obj := ID3MainHeader.new()

	if is_valid:
		header_obj.isId3 = true
		header_obj.id3Ver = str(verH) + "." + str(verL)
		header_obj.unsync = bool(flags & 0b10000000)
		header_obj.compress = bool(flags & 0b01000000)
		header_obj.size = size

	bytesShift = 7 if header_obj.unsync else 8
	return header_obj

func _decode_frame_heads() -> Dictionary:
	if !header.isId3:
		return {}

	var frame_start := TAG_HEADER_LENGTH
	var fms: Dictionary = {}

	var file = FileAccess.open(_file_path, FileAccess.READ)
	if not file:
		return {}

	while frame_start < _ID3Header.size:
		file.seek(frame_start)
		var frame_header_bytes = file.get_buffer(FRAME_HEADER_LENGTH)
		if frame_header_bytes.size() < FRAME_HEADER_LENGTH:
			break

		var frame_id := (
			char(frame_header_bytes[0])
			+ char(frame_header_bytes[1])
			+ char(frame_header_bytes[2])
			+ char(frame_header_bytes[3])
		)

		var frame_length = (
			frame_header_bytes[4] << (bytesShift * 3)
			| frame_header_bytes[5] << (bytesShift * 2)
			| frame_header_bytes[6] << bytesShift
			| frame_header_bytes[7]
		)

		if frame_length <= 0:
			break

		fms[frame_id] = [frame_start, frame_length]
		frame_start += (FRAME_HEADER_LENGTH + frame_length)

	file.close()
	return fms
	
	# -------------------------------
# Comment Frame
# -------------------------------

func _getFrameCommentDict(frameName: StringName) -> Dictionary:
	var bytesText := _getFrameBytes(frameName)
	var preparedText := _prepareByteTextToDecode(bytesText)
	bytesText = preparedText[0]
	var lang := bytesText.slice(0, 3).get_string_from_ascii()

	var comment := bytesText.slice(3)
	var shortEnd := comment.find(0x00)
	var longStart := comment.rfind(0x00)
	var shortContent := ""
	var longContent := ""

	if shortEnd > -1:
		shortContent = _decodeByteText(comment.slice(0, shortEnd), preparedText[1])
	else:
		shortContent = _decodeByteText(comment, preparedText[1])

	if longStart > -1:
		longContent = _decodeByteText(comment.slice(longStart + 1), preparedText[1])

	return {"lang": lang, "shortContent": shortContent, "longContent": longContent}


# -------------------------------
# Frame Data Accessors
# -------------------------------

func getFrameData(frameName: StringName) -> Variant:
	if !frames.has(frameName):
		return null

	match frameName:
		"TIT2", "TPE1", "TALB", "TYER", "TKEY":
			return _getFrameDataString(frameName)
		"COMM":
			return _getFrameCommentDict(frameName)
		"APIC":
			return null
		_:
			return null

func _getFrameBytes(frameName: StringName) -> PackedByteArray:
	var frame_info = frames[frameName]
	var start = frame_info[0] + FRAME_HEADER_LENGTH
	var length = frame_info[1]

	var file = FileAccess.open(_file_path, FileAccess.READ)
	if not file:
		return []

	file.seek(start)
	var bytes = file.get_buffer(length)
	file.close()
	return bytes

func _prepareByteTextToDecode(byteText: PackedByteArray) -> Array:
	var isUnicode := byteText[0] > 0
	return [byteText.slice(1), isUnicode]

func _getFrameDataString(frameName: StringName) -> String:
	var bytes := _getFrameBytes(frameName)
	var prepared := _prepareByteTextToDecode(bytes)
	return _decodeByteText(prepared[0], prepared[1])

# -------------------------------
# Text Decoding
# -------------------------------

func _decodeByteText(text: PackedByteArray, isUnicode: bool) -> String:
	if text.is_empty():
		return ""

	if isUnicode:
		if text.size() >= 4:
			var bom := text.slice(0, 4)
			if bom[0] == 0xFF and bom[1] == 0xFE:
				return text.get_string_from_utf16()
			elif bom[0] == 0xFE and bom[1] == 0xFF:
				return text.get_string_from_utf16()
			elif bom[0] == 0x00 and bom[1] == 0x00:
				return text.get_string_from_utf32()
		return text.get_string_from_utf8()
	else:
		var s := text.get_string_from_utf8()
		if not s.is_valid_identifier():
			s = text.get_string_from_ascii()
		return s

# -------------------------------
# Convenience getters
# -------------------------------

func getArtist() -> String:
	for i in 4:
		var data := _ensureString("TPE" + str(i + 1))
		if data != "":
			return data
	return ""

func getTrackName() -> String:
	return _ensureString("TIT2")

func getAlbum() -> String:
	return _ensureString("TALB")

func getYear() -> String:
	return _ensureString("TYER")

func getKey() -> String:
	return _ensureString("TKEY")

func _ensureString(frameName: StringName) -> String:
	var data := getFrameData(frameName)
	return data if data is String else ""
