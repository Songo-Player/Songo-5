extends RefCounted

## Checks and cleans the relative paths browsers send, so nothing can be read or
## written outside the music directory and names work on FAT32/exFAT cards.

const EXTRA_EXTS := ["lrc"]
const MAX_DEPTH := 16
const MAX_NAME_BYTES := 200
const ILLEGAL := "<>:\"|?*"
# Names Windows reserves, with or without an extension
const RESERVED := ["con", "prn", "aux", "nul", "com1", "com2", "com3", "com4", "com5",
	"com6", "com7", "com8", "com9", "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6",
	"lpt7", "lpt8", "lpt9"]

static func allowed_exts() -> Array:
	return SongoDataResource.AUDIO_EXTS + SongoDataResource.IMAGE_EXTS + SongoDataResource.PLAYLIST_EXTS + EXTRA_EXTS

static func is_allowed_type(path: String) -> bool:
	return path.get_extension().to_lower() in allowed_exts()

## The cleaned path, or "" if it isn't acceptable. Characters cards can't store
## become "_"; hidden names and anything that climbs out are refused.
static func clean(path: String) -> String:
	if path == "" or path.begins_with("/") or path.contains("\\"): return ""
	var parts := path.split("/")
	if parts.size() > MAX_DEPTH: return ""
	var cleaned := PackedStringArray()
	for part in parts:
		var name := ""
		for i in part.length():
			var code := part.unicode_at(i)
			name += "_" if code < 32 or code == 127 or ILLEGAL.contains(part[i]) else part[i]
		name = name.strip_edges()
		# Trailing dots and spaces are dropped by FAT, so drop them up front
		while name.ends_with(".") or name.ends_with(" "):
			name = name.left(-1)
		if name == "" or name.begins_with("."): return ""
		if name.to_utf8_buffer().size() > MAX_NAME_BYTES: return ""
		if name.get_slice(".", 0).to_lower() in RESERVED: name = "_" + name
		cleaned.append(name)
	return "/".join(cleaned)
