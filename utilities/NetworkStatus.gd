extends Node
class_name NetworkStatus

signal status_checked(connected: bool)

func is_connected_to_network() -> void:
	# Run the check in a background thread so it doesn’t block the main loop
	var thread := Thread.new()
	thread.start(Callable(self, "_thread_check_connectivity"))


func _thread_check_connectivity() -> void:
	var connected := false
	var client := HTTPClient.new()

	var host := "clients3.google.com"
	var path := "/generate_204"
	var port := 443
	var tls := TLSOptions.client()  # ✅ correct for HTTPS

	var err := client.connect_to_host(host, port, tls)
	if err != OK:
		_emit_status(false)
		return

	var start_time := Time.get_ticks_msec()

	# Wait for connection to establish (max ~3s)
	while client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		client.poll()
		if Time.get_ticks_msec() - start_time > 3000:
			_emit_status(false)
			return
		OS.delay_msec(100)

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		_emit_status(false)
		return

	# Send GET request
	client.request(HTTPClient.METHOD_GET, path, ["User-Agent: GodotNetworkStatus"])
	start_time = Time.get_ticks_msec()

	# Wait for response (max ~5s)
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		if Time.get_ticks_msec() - start_time > 5000:
			_emit_status(false)
			return
		OS.delay_msec(100)

	if client.has_response():
		var code := client.get_response_code()
		connected = (code == 204)

	client.close()
	_emit_status(connected)


# Helper to emit from static context
func _emit_status(connected: bool) -> void:
	call_deferred("emit_signal", "status_checked", connected)
