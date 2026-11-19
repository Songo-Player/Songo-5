@tool
extends RefCounted

# A theme's preview.png: the picture the theme picker in Settings shows.
# Images are fitted to PREVIEW_SIZE (scaled to cover it, then center-cropped)
# and saved in the theme's root folder. Capturing runs Songo with
# utilities/preview_capture.gd's arguments, which shows the theme's main menu,
# saves a screenshot and quits.

const PREVIEW_SIZE := Vector2i(640, 480)
const FILE_NAME := "preview.png"
# Must match utilities/preview_capture.gd.
const THEME_ARG := "--songo-preview-theme="
const OUT_ARG := "--songo-preview-out="
# Where a capture run writes before it's fitted and copied into the theme.
const CAPTURE_TEMP := "res://.godot/songo_preview_capture.png"

static func preview_path(theme_dir: String) -> String:
	return theme_dir.path_join(FILE_NAME)

# The current preview, read from disk (not the import cache, which lags behind
# a file that was just written). null if there isn't one.
static func load_texture(theme_dir: String) -> Texture2D:
	var path := ProjectSettings.globalize_path(preview_path(theme_dir))
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	return ImageTexture.create_from_image(image) if image else null

# Scales the image to cover PREVIEW_SIZE and crops the overflow evenly.
static func fit(image: Image) -> Image:
	var out: Image = image.duplicate()
	if out.is_compressed():
		out.decompress()
	out.convert(Image.FORMAT_RGBA8)
	var target := Vector2(PREVIEW_SIZE)
	var source := Vector2(out.get_size())
	if source == target:
		return out
	var scale := maxf(target.x / source.x, target.y / source.y)
	var scaled := Vector2i(ceili(source.x * scale), ceili(source.y * scale))
	out.resize(scaled.x, scaled.y, Image.INTERPOLATE_LANCZOS)
	var offset := (scaled - PREVIEW_SIZE) / 2
	return out.get_region(Rect2i(offset, PREVIEW_SIZE))

# Fits and saves the image as the theme's preview.png, then has the editor
# (re)import it so the theme picker shows the new one.
static func save(image: Image, theme_dir: String) -> Error:
	var path := preview_path(theme_dir)
	var err := fit(image).save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		return err
	if Engine.is_editor_hint():
		var fs := EditorInterface.get_resource_filesystem()
		if FileAccess.file_exists(path + ".import"):
			fs.update_file(path)
			fs.reimport_files(PackedStringArray([path]))
		else:
			fs.scan()
	return OK

# Arguments for running Songo (this project) to capture the theme.
static func capture_args(theme_dir: String) -> PackedStringArray:
	return PackedStringArray([
		"--path", ProjectSettings.globalize_path("res://"),
		"--resolution", "%dx%d" % [PREVIEW_SIZE.x, PREVIEW_SIZE.y],
		"--",
		THEME_ARG + theme_dir,
		OUT_ARG + ProjectSettings.globalize_path(CAPTURE_TEMP),
	])
