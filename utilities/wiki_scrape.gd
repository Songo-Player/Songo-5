extends Node

class_name WikiScrape

# --- Helper: Fetch bytes from a URL using HTTPClient (supports HTTPS) ---
static func _get_url_bytes(url: String) -> PackedByteArray:
	var use_ssl := url.begins_with("https://")
	var host := ""
	var path := "/"
	var port := 80 if not use_ssl else 443

	# Basic URL parsing
	var prefix_len := 8 if use_ssl else 7
	var rest := url.substr(prefix_len, url.length() - prefix_len)
	var slash_idx := rest.find("/")
	if slash_idx != -1:
		host = rest.substr(0, slash_idx)
		path = rest.substr(slash_idx)
	else:
		host = rest

	var client := HTTPClient.new()
	var tls_options = null
	if use_ssl:
		tls_options = TLSOptions.client()  # ✅ Proper way to enable HTTPS

	var err := client.connect_to_host(host, port, tls_options)
	if err != OK:
		push_error("Failed to connect: %s" % err)
		return PackedByteArray()

	while client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		client.poll()
		await Engine.get_main_loop().process_frame

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		push_error("Connection failed for: %s" % url)
		return PackedByteArray()

	client.request(HTTPClient.METHOD_GET, path, [], "")

	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		await Engine.get_main_loop().process_frame

	if client.get_status() != HTTPClient.STATUS_BODY:
		push_error("Invalid response for: %s" % url)
		return PackedByteArray()

	var body := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() > 0:
			body += chunk
		await Engine.get_main_loop().process_frame

	return body

# --- Helper: Run a Wikipedia search to find the proper title ---
static func _get_wikipedia_title(artist_name: String) -> String:
	var encoded_name := artist_name.uri_encode()
	var search_url := "https://en.wikipedia.org/w/api.php?action=query&format=json&list=search&srsearch=%s&srlimit=1" % encoded_name
	var json_bytes := await _get_url_bytes(search_url)
	if json_bytes.is_empty():
		return ""

	var json_str := json_bytes.get_string_from_utf8()
	var json = JSON.parse_string(json_str)
	if typeof(json) != TYPE_DICTIONARY:
		return ""

	var search_results = json.get("query", {}).get("search", [])
	if search_results.is_empty():
		return ""

	return search_results[0].get("title", "")


# --- Main static: Fetch artist image, with caching and search fallback ---
static func fetch_artist_image(artist_name: String) -> String:
	var safe_name := artist_name.strip_edges().replace(" ", "_")
	var save_path := "user://artist_images/%s.jpg" % safe_name

	# ✅ Skip if already cached
	var dir := DirAccess.open("user://")
	if dir.dir_exists("artist_images") and FileAccess.file_exists(save_path):
		return save_path

	# Ensure directory exists
	if not dir.dir_exists("artist_images"):
		dir.make_dir("artist_images")

	# 🔍 Try to find the proper Wikipedia title
	var title := await _get_wikipedia_title(artist_name)
	if title == "":
		push_warning("No Wikipedia page found for %s" % artist_name)
		return ""

	var encoded_title := title.uri_encode()
	var api_url := "https://en.wikipedia.org/w/api.php?action=query&format=json&prop=pageimages&titles=%s&pithumbsize=180" % encoded_title

	# 1️⃣ Fetch metadata
	var json_bytes := await _get_url_bytes(api_url)
	if json_bytes.is_empty():
		return ""

	var json_str := json_bytes.get_string_from_utf8()
	var json = JSON.parse_string(json_str)
	if typeof(json) != TYPE_DICTIONARY:
		push_warning("Invalid JSON for %s" % artist_name)
		return ""

	var pages = json.get("query", {}).get("pages", {})
	if pages.is_empty():
		push_warning("No pages found for %s" % artist_name)
		return ""

	var page_data = pages.values()[0]
	if not page_data.has("thumbnail"):
		push_warning("No thumbnail found for %s" % artist_name)
		return ""

	var image_url = page_data["thumbnail"].get("source", "")
	if image_url == "":
		push_warning("Empty thumbnail URL for %s" % artist_name)
		return ""

	# 2️⃣ Download the image
	var image_bytes := await _get_url_bytes(image_url)
	if image_bytes.is_empty():
		push_warning("Failed to download image for %s" % artist_name)
		return ""

	# 3️⃣ Save file
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_buffer(image_bytes)
		file.close()
		return save_path
	else:
		push_error("Failed to save image for %s" % artist_name)
		return ""
		
static func fetch_dicebear_avatar(artist_name: String) -> String:

	var cleaned := artist_name.strip_edges().replace(" ", "_")
	var regex := RegEx.new()
	regex.compile("[^A-Za-z0-9_]")
	var safe_name := regex.sub(cleaned, "", true)
	
	var save_path := "user://artist_images/%s.svg" % safe_name

	var dir := DirAccess.open("user://")
	if dir.dir_exists("artist_images") and FileAccess.file_exists(save_path):
		return save_path

	if not dir.dir_exists("artist_images"):
		dir.make_dir("artist_images")

	var encoded_seed := artist_name.uri_encode()
	var dicebear_url := "https://api.dicebear.com/9.x/bottts-neutral/svg?seed=%s" % encoded_seed

	# --- Fetch SVG bytes using HTTPS ---
	var use_ssl := true
	var url_prefix_len := 8  # for "https://"
	var rest := dicebear_url.substr(url_prefix_len)
	var slash_idx := rest.find("/")
	var host := rest.substr(0, slash_idx)
	var path := rest.substr(slash_idx)
	var port := 443

	var client := HTTPClient.new()
	var tls_opts := TLSOptions.client()

	var err := client.connect_to_host(host, port, tls_opts)
	if err != OK:
		push_error("Failed to connect to DiceBear: %s" % err)
		return ""

	while client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		client.poll()
		await Engine.get_main_loop().process_frame

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		push_error("Connection failed for: %s" % dicebear_url)
		return ""

	client.request(HTTPClient.METHOD_GET, path, [], "")

	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		await Engine.get_main_loop().process_frame

	if client.get_status() != HTTPClient.STATUS_BODY:
		push_error("Invalid response for: %s" % dicebear_url)
		return ""

	var body := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() > 0:
			body += chunk
		await Engine.get_main_loop().process_frame

	if body.is_empty():
		push_error("Failed to download avatar for %s" % artist_name)
		return ""

	# --- Save SVG file ---
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_buffer(body)
		file.close()
		return save_path
	else:
		push_error("Failed to save SVG for %s" % artist_name)
		return ""
