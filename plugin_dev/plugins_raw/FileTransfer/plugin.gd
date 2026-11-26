extends SongoPlugin

## Serves a web page on the local network for copying music onto the device.
## Started and stopped from the plugin's page in Settings. It keeps running when
## that page is left, and stops by itself once it's gone unused for a while.

signal state_changed

const FileTransferSettings = preload("settings/file_transfer_settings.gd")
const HttpServer = preload("http_server.gd")
# Covers built by the browser, waiting for the next import (see cover_store.gd)
const CoverStore = preload("cover_store.gd")
const TagStore = preload("tag_store.gd")
const PAGE = "web/index.html"
const IDLE_STOP_MSEC = 15 * 60 * 1000
# Quiet time after the last file before importing, so a batch imports once
const IMPORT_DELAY_MSEC = 5000
const CHECK_SECONDS = 1.0
# Interfaces a browser on the network can't reach this device by
const VIRTUAL_INTERFACES = ["lo", "docker", "br-", "veth", "virbr", "tun", "tap", "rmnet", "ccmni", "dummy"]

var settings = _load_settings()
var server = null
var files_received := 0
var last_file := ""
var _import_pending := false
var _tag_store = null
var _songo_data = SongoDataResource.get_instance()

func _plugin_ready() -> void:
	# Songo versions without the hook build every cover themselves
	if _supports_covers():
		_songo_data.cover_provider = CoverStore.find
	_songo_data.import_finished.connect(_on_import_finished)
	if "record_provider" in _songo_data:
		_tag_store = TagStore.new()
		_songo_data.record_provider = _tag_store.get_records
	var timer := Timer.new()
	timer.wait_time = CHECK_SECONDS
	timer.autostart = true
	timer.timeout.connect(_check)
	add_child(timer)
	# DeviceOS lets the device sleep when music stops, which would cut off a
	# running server. Deferred so this comes after it.
	SongoPlayer.music_stopped.connect(_keep_awake, CONNECT_DEFERRED)

func _exit_tree() -> void:
	# SongoDataResource outlives scripts at exit, so it can't keep a Callable to one
	if _supports_covers(): _songo_data.cover_provider = Callable()
	if _tag_store != null: _songo_data.record_provider = Callable()
	if server != null:
		server.stop()
		server = null

# Saved settings, or fresh defaults if there's no usable save.
func _load_settings():
	if ResourceLoader.exists(FileTransferSettings.SAVE_PATH):
		var saved = ResourceLoader.load(FileTransferSettings.SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if saved != null && saved.get_script() == FileTransferSettings: return saved
	return FileTransferSettings.new()

func is_running() -> bool:
	return server != null

func is_receiving() -> bool:
	return server != null and server.active_uploads() > 0

func music_directories() -> Array:
	return _songo_data.music_directory_paths

## The chosen music directory, or the first if it's been removed. "" if none.
func music_directory() -> String:
	var directories := music_directories()
	if directories.has(settings.music_directory): return settings.music_directory
	return "" if directories.is_empty() else str(directories[0])

func step_music_directory(direction: int) -> void:
	var directories := music_directories()
	if directories.is_empty(): return
	var index := directories.find(music_directory())
	settings.music_directory = str(directories[wrapi(index + direction, 0, directories.size())])

## Returns "" on success, otherwise what went wrong.
func start_server() -> String:
	if server != null: return ""
	var directory := music_directory()
	if directory == "": return "Add a music directory in Data and Storage first"
	if addresses().is_empty(): return "Connect to wifi first"
	var page := FileAccess.get_file_as_bytes(resolve_path(PAGE))
	if page.is_empty(): return "The File Transfer page is missing"
	var new_server = HttpServer.new()
	var root := directory.rstrip("/") if directory != "/" else directory
	var error: String = new_server.start(root, settings.port, settings.require_pin, page, _supports_covers(), _tag_store)
	if error != "": return error
	server = new_server
	server.file_received.connect(_on_file_received)
	server.pin_changed.connect(func(): state_changed.emit())
	server.activity_changed.connect(func(): state_changed.emit())
	files_received = 0
	last_file = ""
	_keep_awake()
	print("FileTransfer: serving %s on port %d" % [root, settings.port])
	state_changed.emit()
	return ""

func stop_server() -> void:
	if server == null: return
	server.stop()
	server = null
	if not SongoPlayer.music_playing: DeviceOS.spawn_chai(["set-idle-suppression", "0"])
	print("FileTransfer: stopped")
	state_changed.emit()

func _keep_awake() -> void:
	if server != null: DeviceOS.spawn_chai(["set-idle-suppression", "1"])

## The addresses a browser on the same network can open, best guess first.
func addresses() -> Array[String]:
	var found: Array[String] = []
	for interface in IP.get_local_interfaces():
		var interface_name := str(interface.get("name", "")).to_lower()
		if VIRTUAL_INTERFACES.any(func(prefix): return interface_name == prefix or (prefix != "lo" and interface_name.begins_with(prefix))): continue
		for address in interface.get("addresses", []):
			# IPv4 only: what someone would want to type
			if not str(address).contains(".") or str(address).begins_with("127.") or str(address).begins_with("169.254."): continue
			if HttpServer.is_private_address(address) and not found.has(address): found.append(address)
	found.sort_custom(func(a, b): return a.begins_with("192.168.") and not b.begins_with("192.168."))
	return found

func _supports_covers() -> bool:
	return "cover_provider" in _songo_data

# Whatever the import didn't use was for albums that already had a cover.
# Left alone mid-transfer, when they're for the next import.
func _on_import_finished() -> void:
	if _import_pending or is_receiving(): return
	CoverStore.clear()
	if _tag_store != null: _tag_store.clear()

func _on_file_received(path: String) -> void:
	files_received += 1
	last_file = path.get_file()
	_import_pending = true
	state_changed.emit()

func _check() -> void:
	if server != null and not is_receiving() and server.idle_msec() > IDLE_STOP_MSEC:
		stop_server()
		UiHelper.flash_message("File Transfer stopped, it hasn't been used for a while")
	if not _import_pending or _songo_data.importing: return
	if server != null and (is_receiving() or server.idle_msec() < IMPORT_DELAY_MSEC): return
	_import_pending = false
	_songo_data.index_mp3s(true)
