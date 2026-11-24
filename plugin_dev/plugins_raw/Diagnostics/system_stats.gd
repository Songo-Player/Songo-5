extends RefCounted

## Reads Songo's own CPU and memory use from Linux's /proc, which every target
## but Windows has (PortMaster/Spruce handhelds, desktop Linux, Android).
## Call sample() about once a second; CPU is worked out from the change since
## the previous sample, so it's unknown (-1) until the second one.
##
## /proc files report a size of 0, so FileAccess.get_as_text() (which reads
## get_length() bytes) returns nothing for them. They're read line by line
## instead.

## Linux's fixed userspace clock tick (USER_HZ), the unit of /proc CPU times.
## It's 100 on every architecture Songo ships for, arm64 included.
const USER_HZ = 100.0

## Songo's share of the whole machine's CPU, 0-100, or -1 when unknown.
var cpu_percent := -1.0
## Songo's resident memory in bytes, or -1 when unknown.
var ram_bytes := -1
## The memory available to apps in bytes (MemTotal), or -1 when unknown.
var ram_total_bytes := -1

var _last_proc_ticks := -1
var _last_total_ticks := -1
var _last_sample_usec := 0
var _total_available := true

## Whether this platform has /proc to read at all.
func is_supported() -> bool:
	return FileAccess.file_exists("/proc/self/stat")

func sample() -> void:
	_sample_cpu()
	ram_bytes = _read_kb_field("/proc/self/status", "VmRSS:") * 1024
	if ram_total_bytes <= 0:
		ram_total_bytes = _read_kb_field("/proc/meminfo", "MemTotal:") * 1024
	if ram_bytes < 0: ram_bytes = -1
	if ram_total_bytes < 0: ram_total_bytes = -1

func ram_percent() -> float:
	if ram_bytes < 0 or ram_total_bytes <= 0: return -1.0
	return 100.0 * ram_bytes / ram_total_bytes

func _sample_cpu() -> void:
	var proc_ticks := _read_proc_ticks()
	var total_ticks := _read_total_ticks() if _total_available else -1
	if total_ticks < 0: _total_available = false
	var now := Time.get_ticks_usec()

	cpu_percent = -1.0
	if proc_ticks >= 0 and _last_proc_ticks >= 0:
		var proc_delta := proc_ticks - _last_proc_ticks
		if _total_available and _last_total_ticks >= 0:
			# Share of all the time every online core had, so 100% means the
			# whole machine is busy with Songo. Cores a handheld switches off
			# don't add ticks, so they don't water the figure down.
			var total_delta := total_ticks - _last_total_ticks
			if total_delta > 0: cpu_percent = 100.0 * proc_delta / total_delta
		else:
			# Newer Android blocks /proc/stat. Fall back to Songo's CPU time
			# against wall time spread across every core.
			var seconds := (now - _last_sample_usec) / 1000000.0
			var cores := maxi(OS.get_processor_count(), 1)
			if seconds > 0.0: cpu_percent = 100.0 * proc_delta / (USER_HZ * seconds * cores)
		if cpu_percent >= 0.0: cpu_percent = clampf(cpu_percent, 0.0, 100.0)

	_last_proc_ticks = proc_ticks
	_last_total_ticks = total_ticks
	_last_sample_usec = now

# utime + stime from /proc/self/stat. The process name (field 2) is in
# parentheses and may contain spaces, so fields are counted from after the
# last ")": field 3 (state) is index 0 there, utime (14) index 11, stime index 12.
func _read_proc_ticks() -> int:
	var line := _read_first_line("/proc/self/stat")
	var name_end := line.rfind(")")
	if name_end == -1: return -1
	var fields := line.substr(name_end + 1).strip_edges().split(" ", false)
	if fields.size() < 13: return -1
	return fields[11].to_int() + fields[12].to_int()

# Sum of the aggregate "cpu" line in /proc/stat. Only the first 8 columns
# (user..steal) count: guest time is already included in user. Old kernels
# have fewer columns, so whatever is there is summed.
func _read_total_ticks() -> int:
	var line := _read_first_line("/proc/stat")
	if not line.begins_with("cpu "): return -1
	var fields := line.split(" ", false)
	var total := 0
	for i in range(1, mini(fields.size(), 9)):
		total += fields[i].to_int()
	return total

func _read_first_line(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	return file.get_line()

# A "Key:   1234 kB" line's number, from files like /proc/meminfo.
func _read_kb_field(path: String, key: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return -1
	while not file.eof_reached():
		var line := file.get_line()
		if line.begins_with(key):
			return line.substr(key.length()).strip_edges().to_int()
	return -1
