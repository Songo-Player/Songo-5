extends SongoPlugin

## Downloads themes from the Songo-5-Themes catalog (the themes.json its theme
## page publishes) into user://external_themes, where Songo's theme picker in
## UI and Customization finds them to apply. Everything happens from the
## plugin's settings page; the work itself lives here, so a download carries
## on if the page is left.
##
## A theme is downloaded as its release zip, which holds one folder named
## after the theme. It's unpacked into a staging folder first and only moved
## into external_themes once it's whole, so a failed download never leaves a
## broken theme behind.

signal catalog_changed
signal theme_changed(theme_id: String)
signal preview_loaded(theme_id: String)

const DEFAULT_CATALOG_URL = "https://songo-player.github.io/Songo-5-Themes/themes.json"
const THEMES_DIR = "user://external_themes"
const WORK_DIR = "user://theme_downloader"
# What was downloaded for each theme, to tell when the catalog has a newer one.
const STATE_PATH = "user://theme_downloader/installed.json"

# Download counts from GitHub's releases. GitHub allows 60 of these requests an
# hour, so the answer, or a failure, is kept for COUNTS_KEEP seconds.
const COUNTS_PATH = "user://theme_downloader/counts.json"
const COUNTS_KEEP = 600
const COUNTS_MAX_PAGES = 5

enum CatalogState { EMPTY, LOADING, READY, FAILED }

## Where the theme list comes from. Downloads and previews given as relative
## links in it are resolved against this.
var catalog_url := DEFAULT_CATALOG_URL
var catalog: Array = []
var catalog_state := CatalogState.EMPTY
var catalog_error := ""

# theme id -> {"request": HTTPRequest, "error": String}
var _jobs := {}
# theme id -> the download's error, kept until the next try
var _errors := {}
var _previews := {}
var _preview_queue: Array[String] = []
var _preview_request: HTTPRequest
var _installed := {}
# {"repo": String, "at": unix time of the last try, "counts": {theme id: count}}
var _counts := {}
var _counts_loading := false

func _plugin_ready() -> void:
	DirAccess.make_dir_recursive_absolute(WORK_DIR)
	DirAccess.make_dir_recursive_absolute(THEMES_DIR)
	_installed = _load_json(STATE_PATH)
	_counts = _load_json(COUNTS_PATH)

##############################
#          CATALOG           #
##############################

func refresh_catalog() -> void:
	if catalog_state == CatalogState.LOADING: return
	catalog_state = CatalogState.LOADING
	catalog_error = ""
	catalog_changed.emit()
	var request := _new_request()
	request.request_completed.connect(_on_catalog_completed.bind(request))
	var err := request.request(catalog_url)
	if err != OK:
		request.queue_free()
		_catalog_failed("Couldn't start the request (%s)" % error_string(err))

func _on_catalog_completed(result: int, code: int, _headers, body: PackedByteArray, request: HTTPRequest) -> void:
	request.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_catalog_failed(_describe_failure(result, code))
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("themes")) != TYPE_ARRAY:
		_catalog_failed("The theme list couldn't be read")
		return
	catalog = []
	for entry in data["themes"]:
		# Built-in themes are listed too, but there's nothing to download.
		if typeof(entry) != TYPE_DICTIONARY or entry.get("builtin", false): continue
		if not _is_valid_id(str(entry.get("id", ""))) or not entry.get("download"): continue
		catalog.append(entry)
	_apply_counts()
	catalog_state = CatalogState.READY
	catalog_changed.emit()
	_refresh_counts()
	for entry in catalog:
		_queue_preview(entry)

func _catalog_failed(message: String) -> void:
	catalog_state = CatalogState.FAILED
	catalog_error = message
	catalog_changed.emit()

func get_entry(theme_id: String) -> Dictionary:
	for entry in catalog:
		if entry["id"] == theme_id: return entry
	return {}

##############################
#      DOWNLOAD COUNTS       #
##############################

# The catalog's counts are from when it was last published. These are current,
# and where they can't be fetched the catalog's stay.
func _refresh_counts() -> void:
	if _counts_loading: return
	var repo := _releases_repo()
	if repo.is_empty(): return
	var age: float = Time.get_unix_time_from_system() - float(_counts.get("at", 0))
	# A negative age means the clock was changed.
	if _counts.get("repo") == repo and age >= 0.0 and age < COUNTS_KEEP: return
	_counts_loading = true
	_request_counts(repo, 1, {})

# owner/name of the GitHub repo the catalog's downloads are released in.
func _releases_repo() -> String:
	var pattern := RegEx.create_from_string("^https://github\\.com/([\\w.-]+/[\\w.-]+)/releases/download/")
	for entry in catalog:
		var found := pattern.search(str(entry["download"]))
		if found != null: return found.get_string(1)
	return ""

func _request_counts(repo: String, page: int, counts: Dictionary) -> void:
	var request := _new_request()
	request.request_completed.connect(_on_counts_completed.bind(repo, page, counts, request))
	if request.request("https://api.github.com/repos/%s/releases?per_page=100&page=%d" % [repo, page]) != OK:
		request.queue_free()
		_finish_counts(repo, null)

func _on_counts_completed(result: int, code: int, _headers, body: PackedByteArray, repo: String, page: int, counts: Dictionary, request: HTTPRequest) -> void:
	request.queue_free()
	var releases = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
	if typeof(releases) != TYPE_ARRAY:
		_finish_counts(repo, null)
		return
	for release in releases:
		var tag := str(release.get("tag_name", ""))
		if tag.begins_with("theme-"):
			var theme_id := tag.trim_prefix("theme-")
			counts[theme_id] = _release_total(release, theme_id)
	if releases.size() == 100 and page < COUNTS_MAX_PAGES:
		_request_counts(repo, page + 1, counts)
	else:
		_finish_counts(repo, counts)

# Added up as publish_releases.py's total_downloads does: the release's zip,
# the ones it replaced, and the count carried over from those already deleted.
func _release_total(release: Dictionary, theme_id: String) -> int:
	var found := RegEx.create_from_string("(?s)<!-- songo-theme: (\\{.*?\\}) -->").search(str(release.get("body", "")))
	var meta = JSON.parse_string(found.get_string(1)) if found != null else null
	if typeof(meta) != TYPE_DICTIONARY: meta = {}
	var by_asset: Dictionary = meta.get("retired", {}).duplicate()
	for asset in release.get("assets", []):
		# JSON numbers are floats here, and the notes key by whole-number text.
		var key := str(int(asset["id"]))
		if asset["name"] == theme_id + ".zip" or by_asset.has(key):
			by_asset[key] = maxi(int(asset["download_count"]), int(by_asset.get(key, 0)))
	var total := int(meta.get("carried", 0))
	for count in by_asset.values(): total += int(count)
	return total

# Null counts mean they couldn't be fetched; the last ones known are kept.
func _finish_counts(repo: String, counts) -> void:
	_counts_loading = false
	if counts == null:
		counts = _counts.get("counts", {}) if _counts.get("repo") == repo else {}
	_counts = {"repo": repo, "at": Time.get_unix_time_from_system(), "counts": counts}
	_save_json(COUNTS_PATH, _counts)
	if _apply_counts(): catalog_changed.emit()

# Counts only ever go up, so the higher one is the newer. True if any changed.
func _apply_counts() -> bool:
	if _counts.is_empty() or _counts.get("repo") != _releases_repo(): return false
	var changed := false
	for entry in catalog:
		var count := int(_counts["counts"].get(entry["id"], 0))
		if entry.get("downloads") == null or count <= int(entry["downloads"]): continue
		entry["downloads"] = count
		changed = true
	return changed

##############################
#           STATUS           #
##############################

func theme_dir(theme_id: String) -> String:
	return THEMES_DIR.path_join(theme_id)

func is_installed(theme_id: String) -> bool:
	return FileAccess.file_exists(theme_dir(theme_id).path_join("theme.json"))

func installed_version(theme_id: String) -> String:
	var info: Dictionary = ThemeManager.parse_theme_json(theme_dir(theme_id)) if is_installed(theme_id) else {}
	return str(info.get("version", ""))

## True when the catalog has something newer than what's installed: another
## version, or the same version with different files.
func has_update(theme_id: String) -> bool:
	var entry := get_entry(theme_id)
	if entry.is_empty() or not is_installed(theme_id): return false
	if str(entry.get("version", "")) != installed_version(theme_id): return true
	var record: Dictionary = _installed.get(theme_id, {})
	if record.get("bytes") == null or entry.get("download_bytes") == null: return false
	return int(record["bytes"]) != int(entry["download_bytes"])

## The themes in external_themes, downloaded here or put there some other way,
## sorted by folder name.
func downloaded_theme_ids() -> Array[String]:
	var ids: Array[String] = []
	for sub_dir in DirAccess.get_directories_at(THEMES_DIR):
		if is_installed(sub_dir): ids.append(sub_dir)
	ids.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
	return ids

func is_active(theme_id: String) -> bool:
	return SongoSettings.get_instance().theme_path == theme_dir(theme_id)

func is_busy(theme_id: String) -> bool:
	return _jobs.has(theme_id)

## 0 to 1, or -1 while the size isn't known yet.
func get_progress(theme_id: String) -> float:
	if not _jobs.has(theme_id): return -1.0
	var request: HTTPRequest = _jobs[theme_id]["request"]
	var total := request.get_body_size()
	if total <= 0: return -1.0
	return clampf(float(request.get_downloaded_bytes()) / total, 0.0, 1.0)

func get_error(theme_id: String) -> String:
	return _errors.get(theme_id, "")

func get_preview(theme_id: String) -> Texture2D:
	return _previews.get(theme_id)

##############################
#          ACTIONS           #
##############################

func download(theme_id: String) -> void:
	var entry := get_entry(theme_id)
	if entry.is_empty() or is_busy(theme_id): return
	_errors.erase(theme_id)
	var zip_path := WORK_DIR.path_join("%s.zip" % theme_id)
	var request := _new_request()
	request.download_file = zip_path
	request.request_completed.connect(_on_download_completed.bind(theme_id, zip_path, request))
	_jobs[theme_id] = {"request": request}
	var err := request.request(_resolve_url(str(entry["download"])))
	if err != OK:
		_finish_job(theme_id, "Couldn't start the download (%s)" % error_string(err))
		return
	theme_changed.emit(theme_id)

func _on_download_completed(result: int, code: int, _headers, _body, theme_id: String, zip_path: String, _request) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(zip_path)
		_finish_job(theme_id, _describe_failure(result, code))
		return
	var error := _install_zip(theme_id, zip_path)
	DirAccess.remove_absolute(zip_path)
	if error.is_empty():
		var entry := get_entry(theme_id)
		_installed[theme_id] = {"version": str(entry.get("version", "")), "bytes": entry.get("download_bytes")}
		_save_state()
	_finish_job(theme_id, error)
	if error.is_empty():
		var name := str(get_entry(theme_id).get("name", theme_id))
		if is_active(theme_id):
			# Its old files were mounted; switching to the new ones straight
			# away keeps the theme from reading from a file that's changed.
			UiHelper.flash_message("%s updated" % name)
			_switch_theme(theme_dir(theme_id))
		else:
			UiHelper.flash_message("%s downloaded" % name)

func _finish_job(theme_id: String, error: String) -> void:
	if _jobs.has(theme_id):
		_jobs[theme_id]["request"].queue_free()
		_jobs.erase(theme_id)
	if error.is_empty(): _errors.erase(theme_id)
	else: _errors[theme_id] = error
	theme_changed.emit(theme_id)

## Applying themes is left to UI and Customization. The exceptions are the
## theme in use being updated (Godot reads a mounted theme's pck from disk as
## it goes, so it's switched to the new files straight away) or deleted (Songo
## goes back to Songo Classic). Either way it's done as Apply in UI and
## Customization does it, ending on the main menu.
func _switch_theme(path: String) -> void:
	UiHelper.close_overlay_panels()
	var settings := SongoSettings.get_instance()
	settings.theme_path = path
	settings.save()
	ThemeManager.set_current_theme(path)
	Controller.history = []
	SongoPlayer.stop()
	Controller.main_menu()

## Deletes a downloaded theme. Deleting the theme in use switches Songo to
## Songo Classic first and goes back to the main menu.
func delete(theme_id: String) -> bool:
	if is_busy(theme_id): return false
	var name := str(get_entry(theme_id).get("name", theme_id))
	if is_active(theme_id):
		_switch_theme(ThemeManager.default_theme_path)
	var err := _remove_tree(theme_dir(theme_id))
	if err != OK:
		UiHelper.flash_message("Couldn't delete the theme (%s)" % error_string(err))
		theme_changed.emit(theme_id)
		return false
	_installed.erase(theme_id)
	_save_state()
	UiHelper.flash_message("%s deleted" % name)
	theme_changed.emit(theme_id)
	return true

##############################
#         INSTALLING         #
##############################

# Unpacks the zip's <theme_id>/ folder into external_themes/<theme_id>.
# Returns "" on success, or what went wrong.
func _install_zip(theme_id: String, zip_path: String) -> String:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return "The download isn't a zip file"
	var root := theme_id + "/"
	var files := zip.get_files()
	for file in files:
		# Everything has to sit inside the theme's own folder.
		if not file.begins_with(root) or ".." in file.split("/") or file.begins_with("/") or "\\" in file:
			zip.close()
			return "The download has files outside the theme's folder"
	if not root + "theme.json" in files or not root + "theme.pck" in files:
		zip.close()
		return "The download isn't a packaged theme"

	var staging := WORK_DIR.path_join("staging").path_join(theme_id)
	_remove_tree(staging)
	for file in files:
		if file.ends_with("/"): continue
		var target := staging.path_join(file.substr(root.length()))
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var out := FileAccess.open(target, FileAccess.WRITE)
		if out == null:
			zip.close()
			_remove_tree(staging)
			return "Couldn't write the theme's files (%s)" % error_string(FileAccess.get_open_error())
		out.store_buffer(zip.read_file(file))
		out.close()
	zip.close()

	var target_dir := theme_dir(theme_id)
	if DirAccess.dir_exists_absolute(target_dir) and _remove_tree(target_dir) != OK:
		_remove_tree(staging)
		return "Couldn't replace the installed copy"
	var err := DirAccess.rename_absolute(staging, target_dir)
	if err != OK:
		_remove_tree(staging)
		return "Couldn't move the theme into place (%s)" % error_string(err)
	return ""

func _remove_tree(path: String) -> Error:
	if not DirAccess.dir_exists_absolute(path): return OK
	for sub_dir in DirAccess.get_directories_at(path):
		var err := _remove_tree(path.path_join(sub_dir))
		if err != OK: return err
	for file in DirAccess.get_files_at(path):
		var err := DirAccess.remove_absolute(path.path_join(file))
		if err != OK: return err
	return DirAccess.remove_absolute(path)

##############################
#          PREVIEWS          #
##############################

func _queue_preview(entry: Dictionary) -> void:
	var theme_id: String = entry["id"]
	if _previews.has(theme_id) or theme_id in _preview_queue or not entry.get("preview"): return
	_preview_queue.append(theme_id)
	if _preview_request == null: _next_preview()

# One at a time, so a long list doesn't open dozens of connections at once.
func _next_preview() -> void:
	while not _preview_queue.is_empty():
		var theme_id: String = _preview_queue.pop_front()
		var entry := get_entry(theme_id)
		if entry.is_empty(): continue
		_preview_request = _new_request()
		_preview_request.request_completed.connect(_on_preview_completed.bind(theme_id))
		if _preview_request.request(_resolve_url(str(entry["preview"]))) == OK: return
		_preview_request.queue_free()
	_preview_request = null

func _on_preview_completed(result: int, code: int, _headers, body: PackedByteArray, theme_id: String) -> void:
	_preview_request.queue_free()
	_preview_request = null
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var image := Image.new()
		if image.load_png_from_buffer(body) == OK:
			_previews[theme_id] = ImageTexture.create_from_image(image)
			preview_loaded.emit(theme_id)
	_next_preview()

##############################
#          HELPERS           #
##############################

func _new_request() -> HTTPRequest:
	var request := HTTPRequest.new()
	request.use_threads = true
	request.timeout = 60.0
	add_child(request)
	return request

func _resolve_url(link: String) -> String:
	if "://" in link: return link
	return catalog_url.get_base_dir().path_join(link)

# A theme id names a folder in external_themes, so it can't climb out of it.
func _is_valid_id(theme_id: String) -> bool:
	return not theme_id.is_empty() and theme_id.is_valid_filename() and not theme_id.begins_with(".")

func _describe_failure(result: int, code: int) -> String:
	match result:
		HTTPRequest.RESULT_SUCCESS: return "The server answered %d" % code
		HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Couldn't connect, check your internet connection"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: return "Couldn't make a secure connection"
		HTTPRequest.RESULT_TIMEOUT: return "The connection timed out"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN, HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "Couldn't save the download"
	return "The download failed (error %d)" % result

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var data = JSON.parse_string(file.get_as_text())
	return data if typeof(data) == TYPE_DICTIONARY else {}

func _save_state() -> void:
	_save_json(STATE_PATH, _installed)

func _save_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(data, "\t"))
