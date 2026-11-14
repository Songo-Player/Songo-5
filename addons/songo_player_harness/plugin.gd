@tool
extends EditorPlugin

# SongoPlayerHarness itself is built into Songodot (its songo_player_harness
# module). This hands Godot's Android Gradle build the plugin AAR built from
# ../SongoBGPlayer/android/plugin, which brings the foreground playback service
# and media session that keep music going with the screen off, and carries the
# music engine library (libsongo_engine.android.arm64.so) the module loads.
# Needs the export preset's "Use Gradle Build" on.
#
# bin/ (ignored by Godot, see its .gdignore) holds SongoBGPlayer's Linux engine
# library and daemon. The module finds them there when Songo runs from this
# folder (the editor), and the PortMaster build copies the arm64 ones next to
# the runtime.

var export_plugin: AndroidExportPlugin

func _enter_tree():
	export_plugin = AndroidExportPlugin.new()
	add_export_plugin(export_plugin)

func _exit_tree():
	remove_export_plugin(export_plugin)
	export_plugin = null

class AndroidExportPlugin extends EditorExportPlugin:
	func _get_name() -> String:
		return "SongoPlayerHarness"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		# Relative to res://addons/
		return PackedStringArray(["songo_player_harness/android/songo_harness-release.aar"])
