@tool
extends Control
## Base for anything drawn in pencil: redraws only when the boil frame
## changes (a few times a second), not every frame.

const P = preload("palette.gd")
const Sketch = preload("sketch.gd")

var _frame := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _process(_delta: float) -> void:
	if not is_visible_in_tree(): return
	var f := Sketch.frame()
	if f != _frame or _always_redraw():
		_frame = f
		queue_redraw()

## Override for things that also change between boil frames.
func _always_redraw() -> bool:
	return false
