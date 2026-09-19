extends PanelContainer
class_name FlashMessage
enum TYPE {NONE, LYRIC, WARN, INFO}

var tween: Tween

func setup(message, persist_time_arg, type:TYPE):
	$Timer.wait_time = persist_time_arg
	%Label.text = message
	
	match type:
		TYPE.NONE:
			%Icon.hide()
		TYPE.LYRIC:
			%Icon.texture = load("res://assets/music.svg")

func _on_timer_timeout() -> void:
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
 
