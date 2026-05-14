shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec4 screen_color = textureLod(screen_texture, SCREEN_UV, 0.0);
    float gray = dot(screen_color.rgb, vec3(0.299, 0.587, 0.114));
    COLOR = vec4(vec3(gray), 1.0);
}