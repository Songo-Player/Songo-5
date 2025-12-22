extends Node
class_name MusicBrainzApi

const MUSICBRAINZ_SEARCH = "https://musicbrainz.org/ws/2/artist/?query=artist:%s&fmt=json"
const FANART_LOOKUP = "https://webservice.fanart.tv/v3/music/%s?api_key=%s"

@export var fanart_api_key := "bd32263c9c4d5a9046cee212d7b84972"

@onready var http := HTTPRequest.new()

func _ready():
	add_child(http)
	get_artist_images("Daft Punk")


func get_artist_images(artist_name: String) -> void:
	var search_url = MUSICBRAINZ_SEARCH % artist_name.uri_encode()
	print("Searching MusicBrainz for:", artist_name)
	http.request(search_url)
	await http.request_completed.connect(_on_search_result)


func _on_search_result(result, response_code, headers, body):
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not data.has("artists"):
		push_error("❌ No valid artist data from MusicBrainz")
		return

	if data["artists"].is_empty():
		push_error("❌ No artists found")
		return

	var artist_id = data["artists"][0].get("id", "")
	if artist_id == "":
		push_error("❌ Artist ID missing")
		return

	var fanart_url = FANART_LOOKUP % [artist_id, fanart_api_key]
	print("Fetching Fanart.tv images:", fanart_url)

	http.request_completed.disconnect(_on_search_result)
	http.request(fanart_url)
	http.request_completed.connect(_on_fanart_result)


func _on_fanart_result(result, response_code, headers, body):
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("❌ Invalid Fanart.tv response")
		return

	var image_keys = [
		"artistthumb",       # portrait images
		"artistbackground",  # large background art
		"artistbanner",      # wide banners
		"artistlogo",        # transparent logo PNGs
		"musiclogo",         # alternate logos
		"hdmusiclogo",       # HD logos
		"musicbanner"        # alternate banners
	]

	var found_any = false
	print("🎨 Image results for artist:", data.get("name", "Unknown"))

	for key in image_keys:
		if data.has(key) and not data[key].is_empty():
			found_any = true
			print("📂", key, ":")
			for img_entry in data[key]:
				var url = img_entry.get("url", "")
				if url != "":
					print("   →", url)

	if not found_any:
		push_warning("⚠️ No images found on Fanart.tv for this artist")

	# disconnect listener to avoid multiple triggers
	http.request_completed.disconnect(_on_fanart_result)
