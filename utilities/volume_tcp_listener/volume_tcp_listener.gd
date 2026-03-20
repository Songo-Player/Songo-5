extends Node

const PORT := 23456
var server := TCPServer.new()

func _ready():
	var use_songo_tcp = OS.get_environment("USE_SONGO_VOL_TCP_SERVER")
	if use_songo_tcp && int(use_songo_tcp) == 1:
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
	UiHelper.vol_container.update_volume(vol)
