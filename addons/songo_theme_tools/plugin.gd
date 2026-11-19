@tool
extends EditorPlugin

# Adds the "Songo Themes" dock (theme_dock.gd).

const ThemeDock := preload("theme_dock.gd")

var dock: Control

func _enter_tree() -> void:
	dock = ThemeDock.new()
	dock.name = "Songo Themes"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)

func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null
