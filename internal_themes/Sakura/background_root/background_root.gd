extends AspectRatioContainer


const TRAIN_RAIN_ID := "train_rain"
const CHAINSAW_ID := "chainsaw"
const CITY_LANDSCAPE_ID := "almost_bedtime"

const BACKGROUND_ASSETS := {
	TRAIN_RAIN_ID: "assets/train_rain_spritesheet.webp",
	CHAINSAW_ID: "assets/chainsaw_spritesheet.webp",
}

var current_background := ""

var sheet_meta: Dictionary
var atlas_texture: AtlasTexture
var current_frame := 0
var frame_timer := 0.0
var spritesheet_playing := false

var city_landscape_layers: Array[TextureRect] = []
var city_landscape_base_speeds: Array[float] = []
var city_landscape_time := 0.0
var city_landscape_playing := false

var flash_artist_credit = false


# Called when the node enters the scene tree for the first time.

func _ready() -> void:
	_collect_city_landscape_layers(%CityLanscape)
	%VideoStreamPlayer.visible = false
	%BackgroundSprite.visible = false
	%CityLanscape.visible = false
	_update_element()
	ThemeManager.theme_settings_updated.connect(_update_element)
	DeviceOS.pseudo_sleep.connect(_on_pseudo_sleep)
	DeviceOS.pseudo_sleep_wake.connect(_on_pseudo_sleep_wake)
	


func _on_pseudo_sleep() -> void:
	if ThemeManager.settings["static_background"]: return
	match current_background:
		TRAIN_RAIN_ID, CHAINSAW_ID: spritesheet_playing = false
		CITY_LANDSCAPE_ID: city_landscape_playing = false


func _on_pseudo_sleep_wake() -> void:
	if ThemeManager.settings["static_background"]: return
	match current_background:
		TRAIN_RAIN_ID, CHAINSAW_ID: spritesheet_playing = true
		CITY_LANDSCAPE_ID: city_landscape_playing = true


func _collect_city_landscape_layers(node: Node) -> void:
	for child in node.get_children():
		if child is TextureRect and child.material is ShaderMaterial:
			city_landscape_layers.append(child)
			city_landscape_base_speeds.append(child.material.get_shader_parameter("scroll_speed"))
		_collect_city_landscape_layers(child)


func _process(delta: float) -> void:
	match current_background:
		TRAIN_RAIN_ID, CHAINSAW_ID: _process_spritesheet(delta)
		CITY_LANDSCAPE_ID: _process_city_landscape(delta)


func _process_spritesheet(delta: float) -> void:
	if not spritesheet_playing or sheet_meta.is_empty(): return
	var fps: float = sheet_meta["fps"]
	var frame_duration := 1.0 / fps
	frame_timer += delta
	while frame_timer >= frame_duration:
		frame_timer -= frame_duration
		current_frame = (current_frame + 1) % int(sheet_meta["frame_count"])
		_update_atlas_region()


func _process_city_landscape(delta: float) -> void:
	if not city_landscape_playing: return
	city_landscape_time += delta
	for layer in city_landscape_layers:
		(layer.material as ShaderMaterial).set_shader_parameter("elapsed_time", city_landscape_time)


func _update_element() -> void:
	var background_id: String = ThemeManager.settings["background"]

	if background_id != current_background:
		if current_background:
			flash_artist_credit = true
		_teardown_background(current_background)
		current_background = background_id
		_setup_background(background_id)
		

	_apply_background_settings()

	var alignment = ThemeManager.settings["background_alignment"]

	if alignment == "left": alignment_horizontal = AspectRatioContainer.ALIGNMENT_BEGIN
	if alignment == "center": alignment_horizontal = AspectRatioContainer.ALIGNMENT_CENTER
	if alignment == "right": alignment_horizontal = AspectRatioContainer.ALIGNMENT_END


func _setup_background(background_id: String) -> void:
	match background_id:
		TRAIN_RAIN_ID, CHAINSAW_ID: _setup_spritesheet(BACKGROUND_ASSETS[background_id])
		CITY_LANDSCAPE_ID: _setup_city_landscape()


func _teardown_background(background_id: String) -> void:
	match background_id:
		TRAIN_RAIN_ID, CHAINSAW_ID: _teardown_spritesheet()
		CITY_LANDSCAPE_ID: _teardown_city_landscape()


# Applies settings (static_background, x_flip_background) that can change
# independently of which background is active, without a full setup/teardown.
func _apply_background_settings() -> void:
	var static_background: bool = ThemeManager.settings["static_background"]
	var mirrored: bool = ThemeManager.settings["x_flip_background"]
	var art_author = "unkown author"

	match current_background:
		TRAIN_RAIN_ID, CHAINSAW_ID:
			spritesheet_playing = not static_background
			%BackgroundSprite.flip_h = mirrored
			var mat := %BackgroundSprite.material as ShaderMaterial
			mat.set_shader_parameter("mirrored", false)
			if current_background == TRAIN_RAIN_ID:
				art_author = "LennSan"
			# else: art_author = "I have no idea, ive tried so hard to find the original"
		CITY_LANDSCAPE_ID:
			city_landscape_playing = not static_background
			var direction := -1.0 if mirrored else 1.0
			for i in city_landscape_layers.size():
				var mat := city_landscape_layers[i].material as ShaderMaterial
				mat.set_shader_parameter("scroll_speed", city_landscape_base_speeds[i] * direction)
			art_author = "KARSIORI STUDIO"
	if flash_artist_credit:
		flash_artist_credit = false
		UiHelper.flash_message("Background art by %s" % art_author)

func _setup_spritesheet(asset_path: String) -> void:
	var full_path = ThemeManager.theme_path + "/" + asset_path
	var meta_path = full_path.get_basename() + ".json"
	sheet_meta = _load_json(meta_path)
	current_frame = 0
	frame_timer = 0.0
	atlas_texture = AtlasTexture.new()
	atlas_texture.atlas = load(full_path)
	_update_atlas_region()
	%BackgroundSprite.texture = atlas_texture
	%BackgroundSprite.visible = true
	spritesheet_playing = true


func _teardown_spritesheet() -> void:
	spritesheet_playing = false
	%BackgroundSprite.visible = false
	%BackgroundSprite.texture = null
	atlas_texture = null
	sheet_meta = {}


func _setup_city_landscape() -> void:
	city_landscape_time = 0.0
	for layer in city_landscape_layers:
		(layer.material as ShaderMaterial).set_shader_parameter("elapsed_time", 0.0)
	%CityLanscape.visible = true
	city_landscape_playing = true


func _teardown_city_landscape() -> void:
	city_landscape_playing = false
	%CityLanscape.visible = false


func _update_atlas_region() -> void:
	if atlas_texture == null or sheet_meta.is_empty(): return
	var frame_width: int = sheet_meta["frame_width"]
	var frame_height: int = sheet_meta["frame_height"]
	var columns: int = sheet_meta["columns"]
	var col := current_frame % columns
	var row := current_frame / columns
	atlas_texture.region = Rect2(col * frame_width, row * frame_height, frame_width, frame_height)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open spritesheet metadata: " + path)
		return {}
	var json = JSON.parse_string(file.get_as_text())
	return json if typeof(json) == TYPE_DICTIONARY else {}
