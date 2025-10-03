extends ItemList

class_name TestItemList

@export var extra_icon: Texture2D
@export var icon_offset: Vector2 = Vector2(-20, -31) # offset relative to item rect

func _ready():
	item_selected.connect(func(_idx): queue_redraw())

func scrolled_to_bottom(tolerance: float = 1.0):
	var v_scroll = get_v_scroll_bar()
	return (v_scroll.value + size.y) >= (v_scroll.max_value - tolerance)
	
func _draw() -> void:
	if not extra_icon:
		return
		
	var idx = get_selected_items()
	if idx.size() == 0: 
		idx = 0
	else:
		idx = idx[0]
	var scroll_offset = Vector2(0, -get_v_scroll_bar().value)
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	
	for i in range(30):
		var target = idx-15+i
		if target >= 0 && target < item_count:
			var rect := get_item_rect(target)
			var pos: Vector2 = rect.position + icon_offset + scroll_offset
			pos.y += (rect.size.y - extra_icon.get_height()) / 2
			draw_texture(extra_icon, pos)
			
			var extra_text: String = str(get_item_metadata(target))
			if extra_text != "":
				# --- Draw right-aligned text ---
				var text_size = font.get_string_size(extra_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				var text_pos = rect.position + scroll_offset
				text_pos.x += rect.size.x - text_size.x - 16 # padding from right
				text_pos.y += (rect.size.y + text_size.y) / 2 - 6

				draw_string(font, text_pos, extra_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
