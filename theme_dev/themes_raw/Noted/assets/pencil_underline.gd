@tool
extends "sketch_control.gd"
## A pencil line along the bottom, like the blank on a worksheet that you
## write your answer on.

@export var color := P.PENCIL_LIGHT
@export var seed := 0

func _draw() -> void:
	Sketch.line(self, Vector2(0, size.y - 2), Vector2(size.x, size.y - 3), color, 1.6, seed, 0.8)
