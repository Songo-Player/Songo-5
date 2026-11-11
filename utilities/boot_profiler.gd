extends Node

# Temporary boot profiler, the first autoload. Does nothing unless run with
# SONGO_BOOT_PROFILE=1, then compiles every class_name script, the autoloads and
# the main scene one at a time and prints how long each took, slowest first.
# A script's time includes compiling any dependencies that weren't loaded before
# it, so totals are accurate but the cost of shared classes lands on whichever
# script pulled them in first. Boot itself isn't representative in this mode,
# since it also loads scripts that normal boot never touches.

func _init() -> void:
	if OS.get_environment("SONGO_BOOT_PROFILE") != "1": return

	var paths: Array[String] = []
	for global_class in ProjectSettings.get_global_class_list():
		paths.append(global_class.path)
	for property in ProjectSettings.get_property_list():
		var setting: String = property.name
		if setting.begins_with("autoload/") && setting != "autoload/BootProfiler":
			paths.append(String(ProjectSettings.get_setting(setting)).trim_prefix("*"))
	paths.append(ProjectSettings.get_setting("application/run/main_scene"))

	var results := []
	var total_start := Time.get_ticks_usec()
	for path in paths:
		if not ResourceLoader.exists(path): continue
		var start := Time.get_ticks_usec()
		load(path)
		results.append([Time.get_ticks_usec() - start, path])
	var total := Time.get_ticks_usec() - total_start

	results.sort_custom(func(a, b): return a[0] > b[0])
	print("BOOT PROFILE: %d scripts/scenes, %.1f ms total" % [results.size(), total / 1000.0])
	for result in results:
		print("BOOT PROFILE: %8.1f ms  %s" % [result[0] / 1000.0, result[1]])
