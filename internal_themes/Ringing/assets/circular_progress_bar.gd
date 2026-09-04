extends Control
class_name CircularProgressBar

@export var radius := 40.0
@export var thickness := 6.0
@export var progress_color := Color("93c572")
@export var track_color := Color(1, 1, 1, 0.15)
@export var show_track := true
@export var rounded_caps := true

@export_range(0.0, 1.0, 0.001) var progress := 0.0:
	set(value):
		progress = clamp(value, 0.0, 1.0)
		queue_redraw()

# Godot arc angles: 0 = 3 o'clock, increasing = clockwise.
const TOP_ANGLE := -PI / 2.0
const BOTTOM_ANGLE := PI / 2.0

func _draw() -> void:
	var center = size * 0.5
	var segments = max(8, int(radius * 0.5 / 2.0)) # per half-arc, scales with size

	if show_track:
		draw_arc(center, radius, 0.0, TAU, segments * 4, track_color, thickness, true)

	if progress <= 0.0:
		return

	var half_sweep = progress * PI

	# Right arc: grows from top, clockwise, toward bottom
	var right_start = TOP_ANGLE
	var right_end = TOP_ANGLE + half_sweep
	draw_arc(center, radius, right_start, right_end, segments, progress_color, thickness, true)

	# Left arc: grows from bottom, clockwise (through the left side), toward top
	var left_start = BOTTOM_ANGLE
	var left_end = BOTTOM_ANGLE + half_sweep
	draw_arc(center, radius, left_start, left_end, segments, progress_color, thickness, true)

	if rounded_caps:
		var cap_radius = thickness * 0.5

		# Anchor points (top/bottom) - only need capping once each, but drawing
		# both is harmless since they overlap at the same spot until progress > 0
		var top_point = center + Vector2(cos(TOP_ANGLE), sin(TOP_ANGLE)) * radius
		var bottom_point = center + Vector2(cos(BOTTOM_ANGLE), sin(BOTTOM_ANGLE)) * radius
		draw_circle(top_point, cap_radius, progress_color)
		draw_circle(bottom_point, cap_radius, progress_color)

		# Growing tips - skip once they've reached the opposite anchor (progress = 1)
		# to avoid double-stacking a cap exactly on top of the anchor point
		if progress < 1.0:
			var right_tip = center + Vector2(cos(right_end), sin(right_end)) * radius
			var left_tip = center + Vector2(cos(left_end), sin(left_end)) * radius
			draw_circle(right_tip, cap_radius, progress_color)
			draw_circle(left_tip, cap_radius, progress_color)
