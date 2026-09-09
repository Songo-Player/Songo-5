extends PanelContainer

@onready var tween := create_tween()

func setup(message, persist_time_arg):
	$Timer.wait_time = persist_time_arg
	%Label.text = message

func _on_timer_timeout() -> void:
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
 
