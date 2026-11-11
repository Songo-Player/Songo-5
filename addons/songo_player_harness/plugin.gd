@tool
extends EditorPlugin

# Hands Godot's Android Gradle build the harness's plugin AAR (built from
# songo_player_harness/android/plugin), which brings the foreground playback
# service and media session that keep music going with the screen off. Needs
# the export preset's "Use Gradle Build" on.

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
