extends RefCounted

## A small HTTP server for the File Transfer page, on a thread of its own so a
## transfer doesn't stall Songo and isn't limited by its frame rate. Upload
## bodies go to a temporary file as they arrive, and are moved into place only
## once complete. Connections are kept open between requests, so sending many
## small files isn't spent reconnecting.
##
##   GET  /                     the page
##   GET  /api/info             whether a PIN is needed, accepted file types
##   GET  /api/list?path=       folders and files in a folder ("" is the top)
##   POST /api/exists           a JSON array of paths; which are already there
##   PUT  /api/upload?path=     the file as the raw body; &replace=1 to overwrite
##   PUT  /api/cover?path=      a ready-made cover for a song already sent
##
## /api needs an X-Songo header, which other websites' pages can't send here
## without a CORS preflight this never answers, and (except info) the PIN in
## X-Songo-Pin. Only private network addresses are served.

# All emitted deferred, so on the main thread.
signal file_received(path: String)
signal pin_changed
signal activity_changed

const UploadPath = preload("upload_path.gd")
const CoverStore = preload("cover_store.gd")

const TEMP_DIR := ".songo_upload"
const MAX_CONNECTIONS := 8
const MAX_QUERY_BYTES := 512 * 1024
const MAX_HEADER_BYTES := 16384
const CHUNK_BYTES := 131072
# Read from one connection before the others get a turn
const CHUNKS_PER_TURN := 8
const STALL_MSEC := 30000
# How long to rest when there's nothing to do: barely while data is flowing, as
# the next of it is on its way, longer once things go quiet
const REST_ACTIVE_MSEC := 2
const REST_QUIET_MSEC := 20
const ACTIVE_WINDOW_MSEC := 500
const MAX_PIN_FAILURES := 5
# Left free on the card for Songo's own data
const RESERVE_BYTES := 16 * 1024 * 1024

enum State { HEADERS, BODY, RESPOND, DRAIN }

class Connection:
	var peer: StreamPeerTCP
	var state: int = State.HEADERS
	var last_msec: int = 0
	var buffer := PackedByteArray()
	var remaining: int = 0
	var body_size: int = 0
	var file: FileAccess
	# Set when the body goes to buffer rather than a file: called with the
	# connection once it's all there
	var on_body := Callable()
	var keep_alive := false
	var served := 0
	var temp_path := ""
	var dest := ""
	var replace := false
	var out := PackedByteArray()
	var out_pos: int = 0

var _root := ""
var _require_pin := true
var _page := PackedByteArray()
var _covers := false
var _tag_store = null # tag_store.gd, or null
var _server := TCPServer.new()
var _thread: Thread
var _mutex := Mutex.new()
# Shared with the main thread, under _mutex
var _stop := false
var _pin := ""
var _active_uploads := 0
var _last_activity_msec := 0
# Server thread only
var _connections: Array[Connection] = []
var _pin_failures := 0
var _temp_count := 0

## Returns "" on success, otherwise what went wrong.
func start(root: String, port: int, require_pin: bool, page: PackedByteArray, covers: bool, tag_store) -> String:
	_root = root
	_require_pin = require_pin
	_page = page
	_covers = covers
	_tag_store = tag_store
	if not DirAccess.dir_exists_absolute(root): return "The music directory doesn't exist"
	_remove_temp_dir()
	var err := _server.listen(port)
	if err != OK: return "Port %d is in use, try another" % port
	_new_pin()
	_touch()
	_thread = Thread.new()
	err = _thread.start(_run)
	if err != OK:
		_server.stop()
		return "Couldn't start the server (%s)" % error_string(err)
	return ""

## Waits for the server thread. Unfinished uploads are dropped.
func stop() -> void:
	if _thread == null: return
	_mutex.lock()
	_stop = true
	_mutex.unlock()
	_thread.wait_to_finish()
	_thread = null
	_remove_temp_dir()

func get_pin() -> String:
	_mutex.lock()
	var value := _pin
	_mutex.unlock()
	return value

func active_uploads() -> int:
	_mutex.lock()
	var value := _active_uploads
	_mutex.unlock()
	return value

## Msec since a browser last sent or asked for anything.
func idle_msec() -> int:
	_mutex.lock()
	var value := _last_activity_msec
	_mutex.unlock()
	return Time.get_ticks_msec() - value

##############################
#        SERVER THREAD       #
##############################

func _run() -> void:
	var last_moved := 0
	while true:
		_mutex.lock()
		var stopping := _stop
		_mutex.unlock()
		if stopping: break
		while _server.is_connection_available():
			_accept(_server.take_connection())
		var busy := false
		for connection in _connections.duplicate():
			if _service(connection): busy = true
		if busy: last_moved = Time.get_ticks_msec()
		else: OS.delay_msec(REST_ACTIVE_MSEC if Time.get_ticks_msec() - last_moved < ACTIVE_WINDOW_MSEC else REST_QUIET_MSEC)
	for connection in _connections.duplicate():
		_close(connection)
	_server.stop()

func _accept(peer: StreamPeerTCP) -> void:
	if peer == null: return
	if _connections.size() >= MAX_CONNECTIONS: _close_an_idle_one()
	if _connections.size() >= MAX_CONNECTIONS or not is_private_address(peer.get_connected_host()):
		peer.disconnect_from_host()
		return
	peer.set_no_delay(true)
	var connection := Connection.new()
	connection.peer = peer
	connection.last_msec = Time.get_ticks_msec()
	_connections.append(connection)

# Makes room for a new connection by dropping one that's only being kept open.
func _close_an_idle_one() -> void:
	for c in _connections:
		if c.state == State.HEADERS and c.served > 0 and c.buffer.is_empty():
			_close(c)
			return

# Returns whether anything moved, so the thread knows when it can rest.
func _service(c: Connection) -> bool:
	c.peer.poll()
	var moved := false
	match c.state:
		State.HEADERS: moved = _read_headers(c)
		State.BODY: moved = _read_body(c)
		State.RESPOND: moved = _send(c)
		State.DRAIN: moved = _drain(c)
	if moved:
		c.last_msec = Time.get_ticks_msec()
	elif c.peer.get_status() != StreamPeerTCP.STATUS_CONNECTED or Time.get_ticks_msec() - c.last_msec > STALL_MSEC:
		_close(c)
	return moved

func _read(c: Connection, limit: int) -> PackedByteArray:
	if c.peer.get_status() != StreamPeerTCP.STATUS_CONNECTED: return PackedByteArray()
	var available := mini(c.peer.get_available_bytes(), limit)
	if available <= 0: return PackedByteArray()
	var result := c.peer.get_partial_data(available)
	return result[1] if result[0] == OK else PackedByteArray()

func _read_headers(c: Connection) -> bool:
	var data := _read(c, MAX_HEADER_BYTES)
	if data.is_empty(): return false
	c.buffer.append_array(data)
	var end := _find_header_end(c.buffer)
	if end >= 0:
		var head := c.buffer.slice(0, end).get_string_from_utf8()
		var rest := c.buffer.slice(end + 4)
		c.buffer = PackedByteArray()
		_handle(c, head, rest)
	elif c.buffer.size() > MAX_HEADER_BYTES:
		_respond_error(c, 431, "Request too large")
	return true

func _find_header_end(data: PackedByteArray) -> int:
	var from := data.find(13)
	while from >= 0 and from + 3 < data.size():
		if data[from + 1] == 10 and data[from + 2] == 13 and data[from + 3] == 10: return from
		from = data.find(13, from + 1)
	return -1

func _handle(c: Connection, head: String, rest: PackedByteArray) -> void:
	var lines := head.split("\r\n")
	var request := lines[0].split(" ")
	if request.size() != 3 or not request[2].begins_with("HTTP/1."):
		_respond_error(c, 400, "Bad request")
		return
	var headers := {}
	for i in range(1, lines.size()):
		var colon := lines[i].find(":")
		if colon > 0: headers[lines[i].left(colon).strip_edges().to_lower()] = lines[i].substr(colon + 1).strip_edges()

	var method := request[0]
	var path := request[1].get_slice("?", 0)
	var query := _parse_query(request[1].substr(path.length() + 1))
	var length_text: String = headers.get("content-length", "0")
	if headers.has("transfer-encoding") or not length_text.is_valid_int() or int(length_text) < 0:
		_respond_error(c, 411, "A content length is required")
		return
	c.body_size = int(length_text)
	# Whatever of the body isn't read by an upload is drained after responding
	c.remaining = maxi(c.body_size - rest.size(), 0)
	# More than one request at once (browsers don't) isn't supported
	c.keep_alive = request[2] == "HTTP/1.1" and headers.get("connection", "").to_lower() != "close" and rest.size() <= c.body_size

	# A hostname could be another site's, pointed here (DNS rebinding)
	if not is_allowed_host(headers.get("host", "")):
		_respond_error(c, 403, "Open this page by the device's IP address")
		return
	if path == "/" and method == "GET":
		_touch()
		_respond(c, 200, "text/html; charset=utf-8", _page)
		return
	if not path.begins_with("/api/"):
		_respond_error(c, 404, "Not found")
		return
	if not headers.has("x-songo"):
		_respond_error(c, 403, "Missing X-Songo header")
		return
	_touch()
	if path == "/api/info" and method == "GET":
		_respond_json(c, 200, {"pin": _require_pin, "folder": _root.get_file(), "covers": _covers, "types": UploadPath.allowed_exts()})
		return
	if _require_pin and not _check_pin(headers.get("x-songo-pin", "")):
		_respond_error(c, 401, "Wrong PIN")
		return
	match [method, path]:
		["GET", "/api/list"]: _handle_list(c, query.get("path", ""))
		["POST", "/api/exists"]: _take_body(c, rest, MAX_QUERY_BYTES, _finish_exists)
		["PUT", "/api/upload"]: _handle_upload(c, query, headers, rest)
		["PUT", "/api/cover"]: _handle_cover(c, query.get("path", ""), rest)
		_: _respond_error(c, 404, "Not found")

# An empty PIN is the page finding out it needs one, not a guess.
func _check_pin(given: String) -> bool:
	if given == get_pin():
		_pin_failures = 0
		return true
	if given == "": return false
	_pin_failures += 1
	if _pin_failures >= MAX_PIN_FAILURES:
		# Guessing gets nowhere: the PIN on the device's screen changes
		_new_pin()
	return false

func _handle_list(c: Connection, path: String) -> void:
	var dir_path := _root
	if path != "":
		var cleaned := UploadPath.clean(path)
		# Folders already there may have names clean() would change; those
		# can't be opened, only ones it leaves as they are
		if cleaned == "" or cleaned != path:
			_respond_error(c, 400, "That folder can't be opened")
			return
		dir_path = _root.path_join(cleaned)
	var dir := DirAccess.open(dir_path)
	if dir == null:
		_respond_error(c, 404, "That folder isn't there")
		return
	var folders := Array(dir.get_directories()).filter(func(n): return UploadPath.clean(n) == n)
	var files := Array(dir.get_files()).filter(func(n): return not n.begins_with(".") and UploadPath.is_allowed_type(n))
	var natural := func(a, b): return a.naturalnocasecmp_to(b) < 0
	folders.sort_custom(natural)
	files.sort_custom(natural)
	_respond_json(c, 200, {"folders": folders, "files": files, "free": dir.get_space_left()})

# Names that can't be used aren't there; uploading one says what's wrong.
func _finish_exists(c: Connection) -> void:
	var paths = JSON.parse_string(c.buffer.get_string_from_utf8())
	if typeof(paths) != TYPE_ARRAY:
		_respond_error(c, 400, "Bad request")
		return
	var exists := []
	for path in paths:
		var cleaned := UploadPath.clean(str(path))
		exists.append(cleaned != "" and FileAccess.file_exists(_root.path_join(cleaned)))
	_respond_json(c, 200, {"exists": exists})

# Reads the body into the connection's buffer, then calls on_body.
func _take_body(c: Connection, rest: PackedByteArray, limit: int, on_body: Callable) -> void:
	if c.body_size <= 0 or c.body_size > limit:
		_respond_error(c, 400, "Bad request")
		return
	c.on_body = on_body
	c.state = State.BODY
	c.remaining = c.body_size
	_store(c, rest.slice(0, mini(rest.size(), c.body_size)))

func _handle_upload(c: Connection, query: Dictionary, headers: Dictionary, rest: PackedByteArray) -> void:
	var cleaned := UploadPath.clean(query.get("path", ""))
	if cleaned == "" or not UploadPath.is_allowed_type(cleaned):
		_respond_error(c, 400, "That file name or type can't be used")
		return
	if not headers.has("content-length"):
		_respond_error(c, 411, "A content length is required")
		return
	c.dest = _root.path_join(cleaned)
	c.replace = query.get("replace", "") == "1"
	if DirAccess.dir_exists_absolute(c.dest):
		_respond_error(c, 409, "A folder has that name")
		return
	if FileAccess.file_exists(c.dest) and not c.replace:
		_respond_error(c, 409, "Already there")
		return
	var root_dir := DirAccess.open(_root)
	if root_dir == null:
		_respond_error(c, 500, "The music directory isn't available")
		return
	# 0 is also what an unsupported filesystem reports; a full one fails below
	var free := root_dir.get_space_left()
	if free > 0 and c.body_size + RESERVE_BYTES > free:
		_respond_error(c, 507, "Not enough space on the device")
		return
	DirAccess.make_dir_recursive_absolute(_root.path_join(TEMP_DIR))
	_temp_count += 1
	c.temp_path = _root.path_join(TEMP_DIR).path_join("%d.part" % _temp_count)
	c.file = FileAccess.open(c.temp_path, FileAccess.WRITE)
	if c.file == null:
		c.temp_path = ""
		_respond_error(c, 500, "Couldn't write to the music directory")
		return
	_add_active(1)
	c.state = State.BODY
	c.remaining = c.body_size
	_store(c, rest.slice(0, mini(rest.size(), c.body_size)))

func _handle_cover(c: Connection, path: String, rest: PackedByteArray) -> void:
	var cleaned := UploadPath.clean(path)
	var song := _root.path_join(cleaned)
	if not _covers or cleaned == "" or not cleaned.get_extension().to_lower() in SongoDataResource.AUDIO_EXTS or not FileAccess.file_exists(song):
		_respond_error(c, 404, "There's no song there")
		return
	c.dest = song
	_take_body(c, rest, CoverStore.MAX_BYTES, _finish_cover)

func _finish_cover(c: Connection) -> void:
	if CoverStore.store(c.dest, c.buffer): _respond_json(c, 201, {"ok": true})
	else: _respond_error(c, 400, "That cover can't be used")

func _read_body(c: Connection) -> bool:
	var moved := false
	for i in CHUNKS_PER_TURN:
		if c.state != State.BODY: break
		var data := _read(c, mini(CHUNK_BYTES, c.remaining))
		if data.is_empty(): break
		moved = true
		_store(c, data)
	if moved: _touch()
	return moved

func _store(c: Connection, data: PackedByteArray) -> void:
	if c.on_body.is_valid():
		c.buffer.append_array(data)
		c.remaining -= data.size()
		if c.remaining <= 0: c.on_body.call(c)
		return
	if not data.is_empty():
		c.file.store_buffer(data)
		c.remaining -= data.size()
		if c.file.get_error() != OK:
			_drop_upload(c)
			_respond_error(c, 507, "Couldn't write the file, the device may be full")
			return
	if c.remaining <= 0: _finish_upload(c)

func _finish_upload(c: Connection) -> void:
	c.file.flush()
	var write_error := c.file.get_error()
	c.file.close()
	c.file = null
	# close() can be what finds the card full, so check what was written
	var written := FileAccess.open(c.temp_path, FileAccess.READ)
	var size := written.get_length() if written != null else -1
	written = null
	if write_error != OK or size != c.body_size:
		_drop_upload(c)
		_respond_error(c, 507, "Couldn't write the file, the device may be full")
		return
	# Another upload may have made it meanwhile
	if FileAccess.file_exists(c.dest) and not c.replace:
		_drop_upload(c)
		_respond_error(c, 409, "Already there")
		return
	DirAccess.make_dir_recursive_absolute(c.dest.get_base_dir())
	var err := DirAccess.rename_absolute(c.temp_path, c.dest)
	if err != OK:
		_drop_upload(c)
		_respond_error(c, 500, "Couldn't save the file")
		return
	c.temp_path = ""
	if _tag_store != null: _tag_store.read(c.dest)
	_add_active(-1)
	call_deferred("emit_signal", "file_received", c.dest)
	_respond_json(c, 201, {"ok": true})

func _drop_upload(c: Connection) -> void:
	if c.temp_path == "": return
	if c.file != null:
		c.file.close()
		c.file = null
	DirAccess.remove_absolute(c.temp_path)
	c.temp_path = ""
	_add_active(-1)

func _send(c: Connection) -> bool:
	if c.peer.get_status() != StreamPeerTCP.STATUS_CONNECTED: return false
	var result := c.peer.put_partial_data(c.out.slice(c.out_pos, c.out_pos + CHUNK_BYTES))
	if result[0] != OK:
		_close(c)
		return false
	c.out_pos += result[1]
	if c.out_pos >= c.out.size():
		if c.keep_alive: _await_next(c)
		else: c.state = State.DRAIN
	return result[1] > 0

# Ready for another request on the same connection.
func _await_next(c: Connection) -> void:
	c.state = State.HEADERS
	c.served += 1
	c.buffer = PackedByteArray()
	c.out = PackedByteArray()
	c.out_pos = 0
	c.remaining = 0
	c.body_size = 0
	c.dest = ""
	c.replace = false
	c.on_body = Callable()

# Closing with part of a body unread resets the connection, which can lose the
# response, so a refused upload is read to its end and thrown away.
func _drain(c: Connection) -> bool:
	if c.remaining <= 0:
		_close(c)
		return true
	var data := _read(c, CHUNK_BYTES)
	c.remaining -= data.size()
	return not data.is_empty()

func _close(c: Connection) -> void:
	_drop_upload(c)
	c.peer.disconnect_from_host()
	_connections.erase(c)

##############################
#          RESPONSES         #
##############################

const REASONS := {200: "OK", 201: "Created", 400: "Bad Request", 401: "Unauthorized",
	403: "Forbidden", 404: "Not Found", 409: "Conflict", 411: "Length Required",
	431: "Request Header Fields Too Large", 500: "Internal Server Error", 507: "Insufficient Storage"}

func _respond_json(c: Connection, status: int, data: Dictionary) -> void:
	_respond(c, status, "application/json; charset=utf-8", JSON.stringify(data).to_utf8_buffer())

func _respond_error(c: Connection, status: int, message: String) -> void:
	_respond_json(c, status, {"error": message})

func _respond(c: Connection, status: int, type: String, body: PackedByteArray) -> void:
	var head := "HTTP/1.1 %d %s\r\n" % [status, REASONS.get(status, "")]
	head += "Content-Type: %s\r\nContent-Length: %d\r\n" % [type, body.size()]
	# Part of the body was never read, so the next request can't be found
	if c.remaining > 0: c.keep_alive = false
	head += "Connection: %s\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n" % ("keep-alive" if c.keep_alive else "close")
	head += "X-Frame-Options: DENY\r\nReferrer-Policy: no-referrer\r\n\r\n"
	c.out = head.to_utf8_buffer()
	c.out.append_array(body)
	c.out_pos = 0
	c.state = State.RESPOND

##############################
#           HELPERS          #
##############################

static func _parse_query(text: String) -> Dictionary:
	var query := {}
	for pair in text.split("&", false):
		var split := pair.find("=")
		if split > 0: query[pair.left(split)] = pair.substr(split + 1).uri_decode()
	return query

## The Host header is an IP address, localhost or a .local name.
static func is_allowed_host(host: String) -> bool:
	if host.begins_with("["): return host.get_slice("]", 0).substr(1).is_valid_ip_address()
	var name := host.get_slice(":", 0).to_lower()
	return name.is_valid_ip_address() or name == "localhost" or name.ends_with(".local")

## Loopback, link-local and private ranges (IPv4, IPv4-mapped and IPv6).
static func is_private_address(address: String) -> bool:
	var ip := address.to_lower().get_slice("%", 0)
	if ip.begins_with("::ffff:"): ip = ip.substr(7)
	elif ip.begins_with("0:0:0:0:0:ffff:"): ip = ip.substr(15)
	if ip.contains("."):
		var parts := ip.split(".")
		if parts.size() != 4: return false
		var a := int(parts[0])
		var b := int(parts[1])
		return a == 10 or a == 127 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168) or (a == 169 and b == 254)
	if ip == "::1" or ip == "0:0:0:0:0:0:0:1": return true
	var first := ip.get_slice(":", 0)
	if first.length() != 4: return false
	return first.begins_with("fc") or first.begins_with("fd") or first.left(3) in ["fe8", "fe9", "fea", "feb"]

func _new_pin() -> void:
	_pin_failures = 0
	var bytes := Crypto.new().generate_random_bytes(4)
	_mutex.lock()
	_pin = "%06d" % (bytes.decode_u32(0) % 1000000)
	_mutex.unlock()
	call_deferred("emit_signal", "pin_changed")

func _touch() -> void:
	_mutex.lock()
	_last_activity_msec = Time.get_ticks_msec()
	_mutex.unlock()

func _add_active(amount: int) -> void:
	_mutex.lock()
	_active_uploads += amount
	_mutex.unlock()
	call_deferred("emit_signal", "activity_changed")

func _remove_temp_dir() -> void:
	var temp := _root.path_join(TEMP_DIR)
	var dir := DirAccess.open(temp)
	if dir == null: return
	for file_name in dir.get_files():
		if file_name.ends_with(".part"): dir.remove(file_name)
	DirAccess.remove_absolute(temp)
