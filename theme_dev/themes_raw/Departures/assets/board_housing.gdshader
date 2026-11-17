shader_type canvas_item;
// The board's housing: dark louvred slats, a faint glow of the board's own
// lettering from above, and darker corners. Static, so it costs almost nothing.

uniform vec4 base_color : source_color = vec4(0.043, 0.051, 0.063, 1.0);
uniform vec4 glow_color : source_color = vec4(0.949, 0.761, 0.188, 1.0);
uniform float slat_px = 4.0;
uniform float glow_strength = 0.06;
uniform float slat_strength = 0.35;
uniform float vignette_strength = 0.45;

void fragment() {
	float slat = step(slat_px - 1.0, mod(FRAGCOORD.y, slat_px));
	vec3 c = base_color.rgb * (1.0 - slat_strength * slat);
	c += glow_color.rgb * glow_strength * smoothstep(0.55, 0.0, UV.y);
	float vignette = smoothstep(0.95, 0.35, distance(UV, vec2(0.5)));
	c *= mix(1.0 - vignette_strength, 1.0, vignette);
	COLOR = vec4(c, 1.0);
}
