shader_type canvas_item;
// Develops a cover as a black and white print: luminance only, a bit more
// contrast, a faint silver tone. amount = 0 leaves the cover in color.

uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float contrast = 1.18;

void fragment() {
	// COLOR arrives already sampled from the texture and modulated.
	vec4 c = COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	l = clamp((l - 0.5) * contrast + 0.5, 0.0, 1.0);
	vec3 silver = vec3(l) * vec3(1.0, 0.985, 0.95);
	COLOR = vec4(mix(c.rgb, silver, amount), c.a);
}
