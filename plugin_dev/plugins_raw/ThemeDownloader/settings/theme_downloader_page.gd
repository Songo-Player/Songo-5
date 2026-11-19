extends MarginContainer

## Theme Downloader's settings page, linked from Settings via
## "settings_scene_path" in plugin.json. Laid out like the built-in settings
## pages: the catalog, whose Browse opens Songo's theme preview overlay (as
## Change does in UI and Customization, with Download where that has Apply),
## then the downloaded themes listed like the playlists in Data and Storage,
## each with a Delete button.
## The plugin does the downloading; this page shows where things stand.

const DownloadedItem = preload("downloaded_item.tscn")
const CatalogState = preload("../plugin.gd").CatalogState
const ThemePreviewOverlay = preload("res://scenes/theme_preview_overlay/theme_preview_overlay.tscn")

const COLOR_STATUS := Color(0.75, 0.75, 0.75, 1)

var plugin
var theme_index := 0
var _shown_id := ""
var _overlay

func setup(plugin_arg):
	plugin = plugin_arg
	plugin.catalog_changed.connect(_on_catalog_changed)
	plugin.theme_changed.connect(_on_theme_changed)
	plugin.preview_loaded.connect(_on_preview_loaded)
	# The catalog is fetched again each time the page is opened.
	plugin.refresh_catalog()
	_on_catalog_changed()
	build_downloaded_list()

func _ready():
	await get_tree().process_frame
	%PageLabel.grab_focus()
	%ScrollContainer.scroll_vertical = 0

func render_ui():
	pass

func handle_input(_delta: float):
	if Input.is_action_just_pressed("back"):
		Controller.nav_back()

func _process(_delta: float) -> void:
	if _overlay != null and plugin.is_busy(_shown_id):
		_update_action()

##############################
#          CATALOG           #
##############################

func _on_catalog_changed() -> void:
	match plugin.catalog_state:
		CatalogState.LOADING:
			_set_catalog_status("Loading...", COLOR_STATUS)
		CatalogState.FAILED:
			_set_catalog_status(plugin.catalog_error, Color(0.870588, 0, 0, 1))
		CatalogState.READY:
			var count: int = plugin.catalog.size()
			_set_catalog_status("No themes yet" if count == 0 else "%d theme%s" % [count, "" if count == 1 else "s"], COLOR_STATUS)
		_:
			_set_catalog_status("", COLOR_STATUS)
	if plugin.catalog_state == CatalogState.READY:
		# Stay on the theme that was showing, if it's still listed.
		var index := _index_of(_shown_id)
		theme_index = index if index >= 0 else 0
		if plugin.catalog.is_empty():
			if _overlay != null: _overlay.close()
		elif _overlay != null:
			_show_theme()

func _set_catalog_status(text: String, color: Color) -> void:
	%CatalogStatus.text = text
	%CatalogStatus.add_theme_color_override("font_color", color)

func _index_of(theme_id: String) -> int:
	for i in plugin.catalog.size():
		if plugin.catalog[i]["id"] == theme_id: return i
	return -1

##############################
#          OVERLAY           #
##############################

func _open_overlay() -> void:
	_overlay = ThemePreviewOverlay.instantiate()
	_overlay.navigated.connect(_on_navigated)
	_overlay.action_pressed.connect(_on_download_pressed)
	_overlay.closed.connect(func(): _overlay = null)
	_overlay.open()
	_show_theme()

func _show_theme() -> void:
	var entry: Dictionary = plugin.catalog[theme_index]
	_shown_id = entry["id"]
	var tags = entry.get("tags", [])
	_overlay.display({
		"name": str(entry.get("name", _shown_id)),
		"version": str(entry.get("version", "")),
		"author": str(entry.get("author", "")).strip_edges(),
		"co_authors": entry.get("co_authors", []) if typeof(entry.get("co_authors")) == TYPE_ARRAY else [],
		"description": str(entry.get("description", "")),
		"preview": plugin.get_preview(_shown_id),
		"downloads": entry.get("downloads"),
		"tags": tags if typeof(tags) == TYPE_ARRAY else [],
		"ai_usage": entry.get("ai_usage"),
		"can_navigate": plugin.catalog.size() > 1,
	})
	_update_action()

# The action button reads Download, Update, Downloading or Downloaded, with a
# status line for progress, errors or an update.
func _update_action() -> void:
	if _overlay == null: return
	var error: String = plugin.get_error(_shown_id)
	if plugin.is_busy(_shown_id):
		var progress: float = plugin.get_progress(_shown_id)
		_overlay.set_action("Downloading", true)
		_overlay.set_status("Downloading..." if progress < 0.0 else "Downloading... %d%%" % int(progress * 100.0))
	elif error != "":
		_overlay.set_action("Update" if plugin.is_installed(_shown_id) else "Download")
		_overlay.set_status(error, "bad")
	elif plugin.has_update(_shown_id):
		_overlay.set_action("Update")
		_overlay.set_status("A newer version is available.", "notice")
	elif plugin.is_installed(_shown_id):
		_overlay.set_action("Downloaded", true)
		_overlay.set_status("")
	else:
		_overlay.set_action("Download")
		_overlay.set_status("")

##############################
#      DOWNLOADED THEMES     #
##############################

func build_downloaded_list() -> void:
	for child in %DownloadedList.get_children():
		%DownloadedList.remove_child(child)
		child.queue_free()
	var theme_ids: Array[String] = plugin.downloaded_theme_ids()
	for theme_id in theme_ids:
		var item = DownloadedItem.instantiate()
		%DownloadedList.add_child(item)
		item.setup(plugin, theme_id)
		item.deleted.connect(func():
			%PageLabel.grab_focus()
			build_downloaded_list())
	%NoDownloadsLabel.visible = theme_ids.is_empty()

##############################
#           SIGNALS          #
##############################

func _on_theme_changed(theme_id: String) -> void:
	if theme_id == _shown_id: _update_action()
	# A finished download or a delete changes what's in the list.
	if not plugin.is_busy(theme_id): build_downloaded_list()

func _on_preview_loaded(theme_id: String) -> void:
	if _overlay != null and theme_id == _shown_id: _overlay.set_preview(plugin.get_preview(theme_id))

func _on_browse_button_pressed() -> void:
	if plugin.catalog_state != CatalogState.READY or plugin.catalog.is_empty():
		UiHelper.flash_message("The theme catalog hasn't loaded" if plugin.catalog_state != CatalogState.READY else "There are no themes to browse yet")
		return
	_open_overlay()

func _on_navigated(step: int) -> void:
	theme_index = posmod(theme_index + step, plugin.catalog.size())
	_show_theme()

func _on_download_pressed() -> void:
	if plugin.is_busy(_shown_id): return
	plugin.download(_shown_id)
	_update_action()
