extends Node

signal volume_updated(new_val)

const PORT := 23456
# songo.conf key, which the launcher sets to 1 each launch when the CFW reports
# volume changes (chai's volume subscriber), 0 otherwise
const CONF_KEY = "volume_tcp_server"
var server := TCPServer.new()

## Whether the launcher set up volume reports for Songo to listen for.
static func enabled() -> bool:
	return SongoConf.get_value(CONF_KEY) == "1"

func _ready():
	if enabled():
		var err = server.listen(PORT, "127.0.0.1")
		if err != OK:
			push_error("TCP server failed to start: %s" % err)
			queue_free()
			return
	else:
		queue_free()

func _process(_delta):
	if server.is_connection_available():
		var client := server.take_connection()
		var data := client.get_string(client.get_available_bytes()).strip_edges()
		client.disconnect_from_host()

		if data != "":
			on_volume_changed(data)

func on_volume_changed(value: String):
	print("Volume changed:", value)
	var vol := int(value)
	volume_updated.emit(vol)
