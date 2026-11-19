extends RefCounted

# Lets the Songo Theme Tools editor plugin make a theme's preview.png: the
# plugin runs Songo with
#   -- --songo-preview-theme=<theme folder> --songo-preview-out=<png path>
# and songo_app.gd then shows that theme's main menu, saves a screenshot to the
# path and quits. The theme is applied for that run only (the saved theme
# setting isn't changed), the startup library scan and boot message are
# skipped, playback uses its own silent daemon, and the default UI scale and
# content margin are used so previews don't depend on the developer's own
# settings.

const THEME_ARG := "--songo-preview-theme="
const OUT_ARG := "--songo-preview-out="
# Lets the menu finish laying out and animating in before the screenshot.
const SETTLE_SECONDS := 1.5
const DEFAULT_UI_SCALE := 1.0
const DEFAULT_CONTENT_MARGIN := 16
# Under user://. SongoPlayer runs a capture's own silent playback daemon here,
# away from the normal one (and its log).
const SOCKET_DIR := "preview_capture"

static func active() -> bool:
	return theme_path() != "" and out_path() != ""

static func theme_path() -> String:
	return _arg(THEME_ARG)

static func out_path() -> String:
	return _arg(OUT_ARG)

static func _arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""

# Waits for the menu to settle, saves the screenshot and quits. Exit code 0 on
# success, 1 if the image couldn't be saved.
static func capture_and_quit(node: Node) -> void:
	var tree := node.get_tree()
	await tree.create_timer(SETTLE_SECONDS).timeout
	await RenderingServer.frame_post_draw
	var image := node.get_viewport().get_texture().get_image()
	var err := image.save_png(out_path())
	if err != OK:
		push_error("Preview capture: couldn't save %s (%s)" % [out_path(), error_string(err)])
	tree.quit(0 if err == OK else 1)
