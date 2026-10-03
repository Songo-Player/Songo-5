extends SongoPlugin

## Surfaces the bundled station .m3u files as a "Web Radio" main menu list.
## Picking a station plays its first stream in the main song view.

const RadioStation = preload("radio_station.gd")
const WebRadioSettings = preload("settings/web_radio_settings.gd")
const STATIONS_DIR = "stations"
# A stream that has played this long is considered healthy again.
const HEALTHY_STREAM_SEC = 5.0

var stations: Array = []
var settings = _load_settings()
var _failed_streams := 0

func _plugin_ready() -> void:
	_load_stations()
	add_main_menu_item("Web Radio", resolve_path("assets/radio.svg"), open_station_list)

	settings.changed.connect(_apply_stream_options)
	_apply_stream_options()
	SongoPlayer.started_new_song.connect(_on_started_new_song)
	SongoPlayer.stream_error.connect(_on_stream_error)
	SongoPlayer.stream_title_changed.connect(_on_stream_title_changed)

# Saved settings, or fresh defaults if there's no usable save.
func _load_settings():
	if ResourceLoader.exists(WebRadioSettings.SAVE_PATH):
		var saved = ResourceLoader.load(WebRadioSettings.SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if saved != null && saved.get_script() == WebRadioSettings: return saved
	return WebRadioSettings.new()

func _process(_delta: float) -> void:
	if _failed_streams > 0 && SongoPlayer.is_playing() && SongoPlayer.get_playback_position() > HEALTHY_STREAM_SEC:
		_failed_streams = 0

func _load_stations() -> void:
	var stations_path := resolve_path(STATIONS_DIR)
	var files := Array(PluginManager.list_dir(stations_path))
	files.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
	for file_name in files:
		if file_name.get_extension().to_lower() != "m3u": continue
		var station = RadioStation.new()
		station.plugin = self
		if station.load_m3u(stations_path.path_join(file_name)):
			# Same placeholder art playlists get; a no-op once generated.
			station.set_dicebear_image()
			stations.append(station)
	print("WebRadio: loaded %d stations" % stations.size())

# Same behavior as the playlist image buttons in Data and Storage: rebuild only
# fills in missing images, delete clears them all.
func rebuild_station_images() -> void:
	var added := 0
	for station in stations:
		if station.set_dicebear_image(): added += 1
	UiHelper.flash_message("Station images rebuilt (%d images added)" % added)

func delete_station_images() -> void:
	for file_name in DirAccess.get_files_at(RadioStation.IMAGE_DIR):
		var file_path: String = RadioStation.IMAGE_DIR.path_join(file_name)
		var err := DirAccess.remove_absolute(file_path)
		if err != OK: print("WebRadio: failed to remove %s: %s" % [file_path, err])
	UiHelper.flash_message("Station images deleted.")

func _apply_stream_options() -> void:
	SongoPlayer.set_stream_options(settings.stream_buffer_length, settings.network_timeout)

func open_station_list() -> void:
	Controller.collection_list(PluginCollection.new("Web Radio", stations))

func play_station(station) -> void:
	_failed_streams = 0
	var records: Array[TagLibMusicRecord] = []
	records.assign(station.music_records)
	Controller.songs_panel(records, 0)

func _is_station_record(record) -> bool:
	if not SongoPlayer.is_stream_record(record): return false
	for station in stations:
		if station.has_record(record): return true
	return false

# Now playing info is per connection, so drop the last one when switching.
func _on_started_new_song(record) -> void:
	if _is_station_record(record):
		record.artist = record.get_meta("default_artist", RadioStation.DEFAULT_SUBTITLE)

func _on_stream_error(_message: String) -> void:
	var record = SongoPlayer.get_current_music_record()
	if not _is_station_record(record): return

	if settings.auto_failover && _failed_streams < SongoPlayer.music_files.size() - 1:
		_failed_streams += 1
		UiHelper.flash_message("Stream unavailable, trying the next one")
		SongoPlayer.play_next()
	else:
		_failed_streams = 0
		UiHelper.flash_message("Couldn't connect to %s" % record.title)
		SongoPlayer.stop()

func _on_stream_title_changed(title: String) -> void:
	var record = SongoPlayer.get_current_music_record()
	if not _is_station_record(record) || not settings.show_stream_titles: return
	record.artist = title if not title.is_empty() else record.get_meta("default_artist", RadioStation.DEFAULT_SUBTITLE)
	if Controller.active_container is ThemeMainSongView:
		Controller.active_container.refresh_display()
