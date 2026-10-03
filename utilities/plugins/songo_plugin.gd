extends Node
class_name SongoPlugin

## Base class for plugin entry scripts (the "entry" in a plugin's plugin.json).
## PluginManager instantiates the entry script, fills in plugin_info and
## plugin_path, then calls _plugin_ready().
##
## Settings are the plugin's own business: build a settings scene, point
## "settings_scene_path" in plugin.json at it (relative to the plugin root), and
## store values however suits the plugin (a Resource, ConfigFile, JSON...).
## The page is linked from Settings under the plugin's name, and gets
## setup(plugin) called before it's shown if it defines one. Like the built-in
## settings pages it should implement render_ui() and handle_input(delta),
## calling Controller.nav_back() on "back".
##
## Plugin scripts are loaded out of a mounted pck, so they shouldn't declare
## class_name (the global class cache isn't updated for them). Reference other
## plugin scripts via preload/load with resolve_path() instead.

var plugin_info: Dictionary = {}
# res:// path the plugin's files are mounted at, e.g.
# "res://plugin_dev/plugins_raw/WebRadio".
var plugin_path: String = ""

var plugin_name: String:
	get: return plugin_info.get("name", name)

## Override this. Called once after the plugin is added to the tree, before
## the main menu is first built, so menu items registered here show up right away.
func _plugin_ready() -> void:
	pass

func resolve_path(relative_path: String) -> String:
	return plugin_path.path_join(relative_path)

## Adds an entry to the main menu, ahead of Settings/Exit.
func add_main_menu_item(label: String, icon_path: String, action: Callable) -> void:
	Controller.add_menu_item(MenuItemData.new(label, icon_path, action))
