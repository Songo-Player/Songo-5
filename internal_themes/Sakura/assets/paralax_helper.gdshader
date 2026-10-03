shader_type canvas_item;

uniform float scroll_speed : hint_range(-500.0, 500.0) = 20.0; // pixels per second
uniform float elapsed_time = 0.0; // seconds; driven from script instead of built-in TIME so it can be frozen

void fragment() {
    vec2 offset = vec2(scroll_speed * elapsed_time * TEXTURE_PIXEL_SIZE.x, 0.0);
    vec2 scrolled_uv = fract(UV + offset);
    COLOR = texture(TEXTURE, scrolled_uv);
}