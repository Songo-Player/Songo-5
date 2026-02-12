extends MarginContainer

var tween: Tween

func _ready() -> void:
	modulate.a = 0.0

func update_volume(value: int) -> void:
	value = clamp(value, 0, 100)
	modulate.a = 1.0
	var target_size = %VolBar.get_parent().size.y
	# Update UI
	%VolBar.custom_minimum_size.y = (float(value)/100.0)*target_size
	%VolPercent.text = "%d" % value

	# Restart hide timer
	$Timer.start()

	# Kill fade tween if running
	if tween and tween.is_running():
		tween.kill()

func _on_timer_timeout() -> void:
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.5)
