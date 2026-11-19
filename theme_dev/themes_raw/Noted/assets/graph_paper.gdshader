// Graph paper, drawn in code: thin light blue grid lines on white, with a
// faint crumple (soft shading plus a few sharper fold lines) so it reads as
// a real sheet rather than a flat fill. Sized in pixels, so the squares stay
// square at any screen size; background_root.gd keeps rect_size current.
shader_type canvas_item;

uniform vec2 rect_size = vec2(640.0, 480.0);
uniform float cell = 16.0;
uniform vec4 paper : source_color = vec4(0.97, 0.973, 0.98, 1.0);
uniform vec4 line_color : source_color = vec4(0.62, 0.8, 0.88, 1.0);
uniform float line_strength = 0.75;
// How crumpled the sheet looks; 0 is perfectly flat.
uniform float crumple = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 px = UV * rect_size;
	// Distance in pixels to the nearest grid line, either way.
	vec2 to_line = abs(fract(px / cell + 0.5) - 0.5) * cell;
	float line = 1.0 - smoothstep(0.0, 1.0, min(to_line.x, to_line.y));
	vec3 color = mix(paper.rgb, line_color.rgb, line * line_strength);

	// Crumple: broad soft light and shade, plus thin ridges where the
	// paper was folded.
	float soft = noise(px / 110.0) * 0.6 + noise(px / 45.0) * 0.4;
	float ridge = 1.0 - abs(2.0 * noise(px / 140.0 + 7.3) - 1.0);
	float fold = pow(ridge, 10.0);
	color *= 1.0 + crumple * ((soft - 0.5) * 0.05 - fold * 0.035);
	COLOR = vec4(color, 1.0);
}
