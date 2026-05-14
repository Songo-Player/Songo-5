shader_type canvas_item;

uniform bool mirrored = false;

void fragment() {
    vec2 uv = UV;

    if (mirrored) {
        uv.x = 1.0 - uv.x;
    }

    COLOR = texture(TEXTURE, uv);
}
