@tool
extends Control

@onready var button = %MenuItemButton
@onready var icon = %MenuIcon
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	%InnerRotate.rotation_degrees = (rotation_degrees * -1) - get_parent().rotation_degrees
