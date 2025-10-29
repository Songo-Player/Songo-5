shader_type canvas_item;

// This automatically gives access to whatever has already been drawn behind this node
@hint_screen_texture uniform sampler2D screen_texture;

uniform float fade_height : hint_range(0.0, 1.0) = 0.3;
uniform bool fade_from_top = true;

void fragment() {
    // Convert the current pixel position to screen-space UV
    vec2 screen_uv = screen_uv_to_screen(UV);

    // Sample the background (what’s behind this control)
    vec4 bg = texture(screen_texture, screen_uv);

    // Create a vertical fade gradient
    float fade = fade_from_top
        ? smoothstep(0.0, fade_height, UV.y)
        : smoothstep(1.0, 1.0 - fade_height, UV.y);

    // Blend background color with fade alpha
    COLOR = vec4(bg.rgb, 1.0 - fade);
}
