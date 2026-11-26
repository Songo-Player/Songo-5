extends RefCounted

## Tags of songs read as each one arrives, for the next import. A file just
## written is still in memory, so reading it then skips the SD card reads that
## make importing slow, and it's the same reader the import uses. Safe on any
## thread.

# One file, already cached: no read-ahead thread, and don't wait long for it
const READ_OPTIONS := {"threads": 1, "prefetch_ahead": 0, "progress_interval_ms": 1}

var _mutex := Mutex.new()
var _records := {}

func read(song_path: String) -> void:
	if not song_path.get_extension().to_lower() in SongoDataResource.AUDIO_EXTS: return
	var read_records := GDTagLib.build_music_records(PackedStringArray([song_path]), Callable(), READ_OPTIONS)
	if read_records.is_empty(): return
	_mutex.lock()
	_records[song_path] = read_records[0]
	_mutex.unlock()

func get_records() -> Array:
	_mutex.lock()
	var records := _records.values()
	_mutex.unlock()
	return records

func clear() -> void:
	_mutex.lock()
	_records.clear()
	_mutex.unlock()
