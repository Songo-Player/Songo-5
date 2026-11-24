class_name SongoConf

## Options from a songo.conf beside Songo's runtime: in the executable's folder
## or the one above it (PortMaster and spruce ship songo5/songo.conf, with the
## runtime in songo5/runtime/). Only those two, unlike the songo_plugins and
## songo_themes lookups, as "songo.conf" is a common name (the devkit has one of
## its own above where its editor builds land). Its values are defaults: Songo
## uses them in place of its built-in ones, and anything a user sets in Songo's
## own settings still wins.
##
## The file is one key=value per line, with # comments and optional quotes
## around values. A key set to "default" (or empty, or missing) has no value,
## so callers fall back to their own default. With no songo.conf, or one that
## can't be read, every key has no value.
##
##   var accept := SongoConf.get_value("ctrl_accept")          # "" if unset
##   var fps := SongoConf.get_value("target_fps", "60")

const FILE_NAME = "songo.conf"
# The executable's folder, then its parent
const SEARCH_LEVELS = 2
const DEFAULT = "default"

static var _values := {}
static var _path := ""
static var _loaded := false

## The key's value, or fallback when it's unset or "default".
static func get_value(key: String, fallback: String = "") -> String:
	_load()
	var value: String = _values.get(key, "")
	if value == "" or value.to_lower() == DEFAULT: return fallback
	return value

## Whether the key has a value of its own (not unset or "default").
static func has_value(key: String) -> bool:
	return get_value(key) != ""

## Writes key -> value pairs to songo.conf, in place: a key's line is replaced,
## a key the file doesn't have is added at the end, and comments and the rest of
## the file are left as they are. The new values are read back from then on.
## ERR_FILE_NOT_FOUND when there's no songo.conf beside the runtime.
static func set_values(values: Dictionary) -> Error:
	_load()
	if _path == "": return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null: return FileAccess.get_open_error()
	var lines := file.get_as_text().split("\n")
	file.close()
	var remaining := values.duplicate()
	for i in range(lines.size()):
		var line := lines[i].strip_edges()
		if line == "" or line.begins_with("#"): continue
		var split := line.find("=")
		if split <= 0: continue
		var key := line.substr(0, split).strip_edges()
		if remaining.has(key):
			lines[i] = "%s=%s" % [key, remaining[key]]
			remaining.erase(key)
	# Keys it didn't have go before the trailing newline's empty last line
	var insert_at := lines.size() - 1 if lines.size() > 0 and lines[-1] == "" else lines.size()
	for key in remaining:
		lines.insert(insert_at, "%s=%s" % [key, remaining[key]])
		insert_at += 1
	file = FileAccess.open(_path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string("\n".join(lines))
	file.close()
	for key in values:
		_values[key] = str(values[key])
	return OK

## Where the songo.conf in use is, or "" when there's none beside the runtime.
static func path() -> String:
	_load()
	return _path

static func _find() -> String:
	var dir := OS.get_executable_path().get_base_dir()
	for i in range(SEARCH_LEVELS):
		var candidate := dir.path_join(FILE_NAME)
		if FileAccess.file_exists(candidate): return candidate
		dir = dir.get_base_dir()
	return ""

static func _load() -> void:
	if _loaded: return
	_loaded = true
	var conf_path := _find()
	if conf_path == "": return
	var file := FileAccess.open(conf_path, FileAccess.READ)
	if file == null:
		push_warning("SongoConf: couldn't read %s (%s)" % [conf_path, error_string(FileAccess.get_open_error())])
		return
	_path = conf_path
	while not file.eof_reached():
		# strip_edges also drops the \r of a file saved on Windows
		var line := file.get_line().strip_edges()
		if line == "" or line.begins_with("#"): continue
		var split := line.find("=")
		if split <= 0:
			push_warning("SongoConf: ignoring \"%s\" in %s, expected key=value" % [line, conf_path])
			continue
		var value := line.substr(split + 1).strip_edges()
		if value.length() >= 2 and value[0] == value[-1] and value[0] in ["\"", "'"]:
			value = value.substr(1, value.length() - 2)
		_values[line.substr(0, split).strip_edges()] = value
