extends Node
#class_name VolumeTcpListener

const PORT := 23456

var server := TCPServer.new()
var bin_path

func _ready():
	bin_path = OS.get_environment("SONGO_BINARIES_DIR")
	var cfw_name = OS.get_environment("CFW_NAME")
	var setup_path = "%s/%s-volume-handle/setup.sh" % [bin_path, cfw_name]
	
	if !FileAccess.file_exists(setup_path):
		print("No volume setup script found")
		queue_free()
		return
	
	var err = server.listen(PORT, "127.0.0.1")
	if err != OK:
		push_error("TCP server failed to start: %s" % err)
		return
	else:
		print("Volume TCP listener running on port", PORT)
		OS.execute("sh", ["-c", setup_path])

func _process(_delta):
	if server.is_connection_available():
		var client := server.take_connection()
		var data := client.get_string(client.get_available_bytes()).strip_edges()
		client.disconnect_from_host()

		if data != "":
			on_volume_changed(data)

func on_volume_changed(value: String):
	print("Volume changed:", value)
	# Example: convert to int
	var vol := int(value)
	#UiHelper.flash_message("Volume changed to: %s" % value)
	UiHelper.vol_container.update_volume(vol)
